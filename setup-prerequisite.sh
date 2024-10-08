#!/usr/bin/env bash
set -e
echo "Processing $0"
SERVICE_ADMIN_PASSWORD="$SERVICE_PASSWORD-admin"
service_container_name="$SERVICE_NAME-service"
service_container_id=$(docker run -d --rm -p "$SERVICE_PORT:$SERVICE_PORT" \
	-e MARIADB_USER=$SERVICE_USERNAME \
	-e MARIADB_PASSWORD=$SERVICE_PASSWORD \
	-e MARIADB_DATABASE="$DATABASE_NAME" \
	-e MARIADB_ROOT_PASSWORD="$SERVICE_ADMIN_PASSWORD" \
  --name "$service_container_name" \
  --health-cmd "$SERVICE_HEALTH_CMD" \
  --health-interval 10s --health-timeout 5s --health-retries 5 \
  ${SERVICE_IMAGE} --port $SERVICE_PORT)

docker logs -f "$service_container_name" &> "$service_container_name.log" &
echo "Waiting for $service_container_name"
while [ "$( docker container inspect -f '{{.State.Status}}' $service_container_name )" != "running" ]; do
  echo "waiting for $service_container_name to be running, currently: $(docker inspect -f '{{.State.Status}}' $service_container_name)"
  sleep 1
done
while [ "$( docker container inspect -f '{{.State.Health.Status}}' $service_container_name )" != "healthy" ]; do
  echo "waiting for $service_container_name to be healthy, currently: $(docker inspect -f '{{.State.Health.Status}}' $service_container_name)"
  sleep 1
done

if [ -z "$service_container_id" ];then
  echo "ERROR: failed to start container '$service_container_name' using $SERVICE_IMAGE"
else
  echo "'$service_container_name' is running $SERVICE_IMAGE"
fi
service_container_name="$(docker ps -f "ancestor=$SERVICE_IMAGE" --format "{{.Names}}")"
SERVICE_CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service_container_name")
echo "SERVICE_CONTAINER_IP: $SERVICE_CONTAINER_IP"
export SERVICE_HOST=$SERVICE_CONTAINER_IP
docker ps
echo "$SERVICE_NAME - MariaDb  version in $service_container_name: $(docker exec -i $service_container_name mariadb --version)"

echo "$SERVICE_NAME - Connection to database as Root: docker exec -i $service_container_name bash -c \"mariadb-admin --password='$SERVICE_ADMIN_PASSWORD' --host localhost --port $SERVICE_PORT ping\""
docker exec -i $service_container_name bash -c "mariadb-admin --password='$SERVICE_ADMIN_PASSWORD' --host localhost --port $SERVICE_PORT ping"
echo "$SERVICE_NAME - Connection to database as User: docker exec -i $service_container_name bash -c \"mariadb --user $SERVICE_USERNAME --password='$SERVICE_PASSWORD' --host localhost --port $SERVICE_PORT $DATABASE_NAME -e 'SELECT DATABASE();'\""
docker exec -i $service_container_name bash -c "mariadb --user $SERVICE_USERNAME --password='$SERVICE_PASSWORD' --host localhost --port $SERVICE_PORT $DATABASE_NAME -e 'SELECT DATABASE();'"

echo "SERVICE_HOST: $SERVICE_HOST"

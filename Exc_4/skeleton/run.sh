#!/bin/sh
set -e

# 1. Build the orderservice Docker image using multi-stage Dockerfile
echo "Building orderservice image..."
docker build -t orderservice .

# 2. Create persistent volume and start PostgreSQL container if not already running
echo "Starting PostgreSQL database container..."
docker volume create pgdata_18

if [ ! "$(docker ps -q -f name=postgres18-db)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=postgres18-db)" ]; then
        docker start postgres18-db
    else
        docker run -d \
            --name postgres18-db \
            --network host \
            --env-file debug.env \
            -v pgdata_18:/var/lib/postgresql/18/docker \
            postgres:18
    fi
else
    echo "postgres18-db container is already running."
fi

# 3. Start orderservice container
echo "Starting orderservice container..."
if [ "$(docker ps -aq -f name=orderservice)" ]; then
    docker rm -f orderservice
fi

docker run -d \
    --name orderservice \
    --network host \
    --env-file debug.env \
    orderservice

echo "Orderservice is running!"
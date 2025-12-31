# Overview

This project consists of a Python-based web application developed with the Flask framework. Postgres is used for persistent storage. Database setup and configuration is not included. 

# 1 Run SigNoz

```sh
# Download
./signoz.sh download

# Start
./signoz.sh start
```

# 2 Run the application

```sh
docker-compose -f ./compose.yaml up --build -d
```
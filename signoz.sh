#!/bin/bash

# Function to start the services
start_services() {
    echo "Signoz (starting)"
    docker-compose -f ./signoz/repo/deploy/docker/docker-compose.yaml up --detach --remove-orphans
    echo "Signoz (running)"

    until curl -L -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/register | grep 200; do
        sleep 1
    done

    curl -Ls -X POST -o /dev/null -H "Content-Type: application/json" -d '{"email":"student@jf.com","name":"Student","orgName":"jf","password":"Blueberry-3.14"}' http://localhost:8080/api/v1/register
    echo "Signoz (admin registered)"
}

# Function to stop the services
stop_services() {
    echo "Signoz (stopping)"
    docker-compose -f ./signoz/repo/deploy/docker/docker-compose.yaml down
    echo "Signoz (stopped)"
}

# Function to download signoz
download_signoz() {
    echo "Signoz (downloading)"
    
    mkdir -p ./signoz 
    pushd ./signoz
    
    # Remove the dir if it's already downloaded.
    rm -rf ./repo
    # Clone the repo
    git clone -b main https://github.com/SigNoz/signoz.git repo 
    
    # Back to the original dir.
    popd
    popd
    echo "Signoz (downloaded)"
}


signoz_status() {
    # Try to detect EC2 public IP; fall back to localhost when metadata is unavailable.
    PUB_ADDRESS=""

    # Get metadata token (short timeout) — fail silently if not available
    AUTH_TOKEN=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
    if [ -n "$AUTH_TOKEN" ]; then
        PUB_ADDRESS=$(curl -s -m 2 -H "X-aws-ec2-metadata-token: $AUTH_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
    fi

    # Choose display host: public IP when present, otherwise localhost
    DISPLAY_HOST="localhost"
    if [ -n "$PUB_ADDRESS" ]; then
        DISPLAY_HOST="$PUB_ADDRESS"
    fi

    # Check Signoz register endpoint on localhost
    HTTP_STATUS=$(curl -L -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/register || echo "000")

    if [ "$HTTP_STATUS" -eq "200" ]; then
        echo "Signoz (running) @ http://$DISPLAY_HOST:8080/"
    else
        # If the URL isn't available, it could be because the service is starting up or images are being pulled.
        SERVICE_EXISTS="$(docker-compose -f ./signoz/repo/deploy/docker/docker-compose.yaml ps --status=running -q 2> /dev/null)"

        if [ -z "$SERVICE_EXISTS" ]; then
            echo "Signoz (ambiguous state)"
            echo "Either the initial images are downloading or the signoz service has not started."
            echo "Recheck the status in a couple minutes."
        else
            echo "Signoz (starting)"
        fi
    fi

}


# Check for command-line arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {start|stop|download|status}"
    exit 1
fi

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    download)
        download_signoz
        ;;
    status)
        signoz_status
        ;;
    *)
        echo "Invalid option: $1"
        echo "Usage: $0 {start|stop|download|status}"
        exit 1
        ;;
esac
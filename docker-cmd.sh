#!/usr/bin/env bash
# File    : docker_project_manager.sh
# Brief   : Script to manage the docker image and container for this project
# Author  : Martin Rizzo | <martinrizzo@gmail.com>
# Date    : Feb 6, 2024
# Repo    : https://github.com/martin-rizzo/SimpleFtpServer
# License : MIT
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                             Simple Ftp Server
#          A lightweight, easy-to-configure FTP server using Docker
#
#     Copyright (c) 2024 Martin Rizzo
#
#     Permission is hereby granted, free of charge, to any person obtaining
#     a copy of this software and associated documentation files (the
#     "Software"), to deal in the Software without restriction, including
#     without limitation the rights to use, copy, modify, merge, publish,
#     distribute, sublicense, and/or sell copies of the Software, and to
#     permit persons to whom the Software is furnished to do so, subject to
#     the following conditions:
#
#     The above copyright notice and this permission notice shall be
#     included in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#     EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#     TORT OR OTHERWISE, ARISING FROM,OUT OF OR IN CONNECTION WITH THE
#     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _


# Define parameters for managing the Docker image and container of the project.
#  - IMAGE_NAME     : Name of the Docker image associated with the project.
#  - CONTAINER_NAME : Name of the Docker container instantiated from the image.
#  - CONTAINER_PARAMETERS :
#      Parameters for configuring the Docker container. These parameters
#      are passed to the 'docker run' command for setting up port mappings,
#      environment variables, volumes, etc.
#      Make sure to properly format them by escaping newline characters '\'.
#
IMAGE_NAME="simple-ftp-server"
CONTAINER_NAME="ftp-server"
CONTAINER_PARAMETERS="
    -p 20:20 
    -p 21:21 
"

#-------------------------------- HELPERS ----------------------------------#

RED='\e[1;31m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
DEFAULT_COLOR='\e[0m'

# Displays a warning message
warning() {
    local message=$1
    echo -e "${YELLOW}WARNING${DEFAULT_COLOR} ${message}"
}

# Displays an error message
error() {
    local message=$1
    echo -e "${RED}ERROR:${DEFAULT_COLOR} ${message}"
}

# Displays a fatal error message and exits the script with status code 1
fatal_error() {
    local message=$1
    error "$message"
    exit 1
}

# Checks if a Docker image exists in the repository
docker_image_exists() {
    docker image inspect "$1" &> /dev/null
}

# Checks if a Docker container is stopped
docker_container_stopped() {
    docker container inspect --format='{{.State.Status}}' "$1" | grep -qi "exited"
}

# Checks if a Docker container exists
docker_container_exists() {
    if [ "$(docker ps -a -q -f name=$1)" ]; then
        return 0  # Container exists
    else
        return 1  # Container does not exist
    fi
}

#-------------------------------- COMMANDS ---------------------------------#

# Build the container
build_image() {

    clear_docker_resources

    # Build the Docker image
    echo "Building the Docker image..."
    if ! docker build -t $IMAGE_NAME . ; then
        fatal_error "Failed to build the Docker image."
    fi
    echo "Done! The container has been built."
}

# Stop and remove container and image
clear_docker_resources() {

    # stop the container if it's running
    if [[ "$(docker ps -q -f name=$CONTAINER_NAME)" ]]; then
        echo "Stopping the existing container..."
        docker stop $CONTAINER_NAME
    fi

    # remove the container if it exists
    if [[ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]]; then
        echo "Removing the existing container..."
        docker rm $CONTAINER_NAME
    fi

    # remove the image if it exists
    if [[ "$(docker images -q $IMAGE_NAME)" ]]; then
        echo "Removing the existing image..."
        docker rmi $IMAGE_NAME
    fi

    echo "Done! Docker resources cleared."
}

# Run the container
run_container() {

    # if the container already exists
    # ensure the container is running
    if docker_container_exists $CONTAINER_NAME ; then
        if docker_container_stopped $CONTAINER_NAME ; then
            echo "Starting existing stopped container..."
            docker start "$CONTAINER_NAME"
        else
            echo "Docker container already running"
        fi
        return
    fi
    
    # if the container doesn't exist
    # check for its image; if not found, build it!
    if ! docker_image_exists $IMAGE_NAME ; then
        build_image
    fi
    
    # start a new container with specified parameters
    echo "Starting new container..."
    echo '>' docker run $CONTAINER_PARAMETERS --name "$CONTAINER_NAME" "$IMAGE_NAME"
    docker run $CONTAINER_PARAMETERS --name "$CONTAINER_NAME" "$IMAGE_NAME"

}

# Stop the container if it's running
stop_container() {
    if [[ "$(docker ps -q -f name=$CONTAINER_NAME)" ]]; then
        echo "Stopping the existing container..."
        docker stop $CONTAINER_NAME
    fi
}

restart_container() {
    stop_container && run_container
}

open_console_in_container() {
    docker exec -it "$CONTAINER_NAME" /bin/sh
}

# List images and containers
list_docker_info() {
    echo
    echo -e '    \e[1;32mDOCKER IMAGES'
    docker images | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
    echo -e '    \e[1;32mDOCKER CONTAINERS'
    docker ps -a  | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
}

show_container_logs() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        echo "Error: The container $CONTAINER_NAME does not exist." >&2
        return 1
    fi
    echo "Showing logs for container $CONTAINER_NAME..."
    docker logs $CONTAINER_NAME
}

execute_command_in_container() {
    fatal_error "Not implemented"
}

show_container_status() {
    fatal_error "Not implemented"
}

# Main script logic
cd src
case "$1" in
    "build")
        build_image
        ;;
    "clean")
        clear_docker_resources
        ;;
    "run")
        run_container
        ;;
    "stop")
        stop_container
        ;;
    "restart")
        restart_container
        ;;
    "console")
        open_console_in_container
        ;;
    "list")
        list_docker_info
        ;;
   "logs")
       show_container_logs
       ;;
   "exec")
       execute_command_in_container
       ;;
   "status")
       show_container_status
       ;;
    *)
        build_image
        ;;
esac

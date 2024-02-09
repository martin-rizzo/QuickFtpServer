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

warning() {
    local message=$1
    echo -e "${YELLOW}WARNING${DEFAULT_COLOR} ${message}"
}

error() {
    local message=$1
    echo -e "${RED}ERROR:${DEFAULT_COLOR} ${message}"
}

fatal_error() {
    local message=$1
    error "$message"
    exit 1
}

#-------------------------------- COMMANDS ---------------------------------#


# Function to list Docker images and containers
list_docker_info() {
    echo
    echo -e '    \e[1;32mDOCKER IMAGES'
    docker images | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
    echo -e '    \e[1;32mDOCKER CONTAINERS'
    docker ps -a  | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
}


# Function to build the container
build_image() {

    clear_docker_resources

    # Build the Docker image
    echo "Building the Docker image..."
    if ! docker build -t $IMAGE_NAME . ; then
        fatal_error "Failed to build the Docker image."
    fi
    echo "Done! The container has been built."
}

# Stop and remove Docker containers (optionally removes Docker images)
#
# Usage: clear_docker_resources [extra_action]
#
# Parameters:
#   [extra_action] - Specify "remove-image" to also remove the
#                    Docker image associated with the container.
#
clear_docker_resources() {
    local extra_action=$1

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
    if [[ $extra_action == 'remove-image' && "$(docker images -q $IMAGE_NAME)" ]]; then
        echo "Removing the existing image..."
        docker rmi $IMAGE_NAME
    fi

    echo "Done! Docker resources cleared."
}

run_container() {
    if ! docker image inspect $IMAGE_NAME &> /dev/null; then
        build_image
    fi
    if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q 'Exited'; then
        echo "Starting existing stopped container..."
        docker start "$CONTAINER_NAME"
        return 0
    else
        echo "Starting new container..."
        echo '>' docker run $CONTAINER_PARAMETERS --name "$CONTAINER_NAME" "$IMAGE_NAME"
        docker run $CONTAINER_PARAMETERS --name "$CONTAINER_NAME" "$IMAGE_NAME"
    fi    
}

# stop the container if it's running
stop_container() {
    if [[ "$(docker ps -q -f name=$CONTAINER_NAME)" ]]; then
        echo "Stopping the existing container..."
        docker stop $CONTAINER_NAME
    fi
}

restart_container() {
    stop_container && run_container
}

show_container_logs() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        echo "Error: The container $CONTAINER_NAME does not exist." >&2
        return 1
    fi
    echo "Showing logs for container $CONTAINER_NAME..."
    docker logs $CONTAINER_NAME
}

open_console_in_container() {
    docker exec -it "$CONTAINER_NAME" /bin/sh
}

# Main script logic
case "$1" in
    "list")
        list_docker_info
        ;;
    "clean")
        clear_docker_resources remove-image
        ;;
    "build")
        build_image
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
#    "logs")
#        show_container_logs
#        ;;
#    "status")
#        show_container_status
#        ;;
#    "push")
#        push_to_registry
#        ;;
#    "pull")
#        pull_from_registry
#        ;;
#    "exec")
#        execute_command_in_container
#        ;;
#    "config")
#        view_edit_container_config
#        ;;
#    "backup")
#        backup_container_data
#        ;;
#    "restore")
#        restore_container_data
#        ;;
#    "inspect")
#        inspect_container
#        ;;
    *)
        build_and_run_ftp_server
        ;;
esac

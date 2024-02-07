#!/usr/bin/env bash
# File    : build.sh
# Brief   : Script to manage the docker images and containers.
# Author  : Martin Rizzo | <martinrizzo@gmail.com>
# Date    : Feb 6, 2024
# Repo    : https://github.com/martin-rizzo/SimpleFtpServer
# License : MIT
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                              Simple Ftp Server
#     Bash tool for easy console-based mounting of remote Samba resources
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


# Define image name and container name
IMAGE_NAME="simple-ftp-server"
CONTAINER_NAME="ftp-server"


# Function to list Docker images and containers
list_docker_info() {
    echo
    echo -e '    \e[1;32mDOCKER IMAGES'
    #echo '--------------'
    #docker images | sed 's/^/    /'
    docker images | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
    echo -e '    \e[1;32mDOCKER CONTAINERS'
    #echo '------------------'
    docker ps -a  | awk 'NR==1 {print "    \033[0;30;42m" $0 "\033[0m"} NR>1 {print "    " $0 }'
    echo
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

# Function to build and run the FTP server container
build_and_run_ftp_server() {

    clear_docker_resources

    # Build the Docker image
    echo "Building the Docker image..."
    docker build -t $IMAGE_NAME .

    # Run the container
    echo "Starting the new container..."
    docker run -d -p 20:20 -p 21:21 --name $CONTAINER_NAME $IMAGE_NAME

    echo "Done! The container has been built and is running."
}


# Main script logic
case "$1" in
    "list")
        list_docker_info
        ;;
    "clean")
        clear_docker_resources remove-image
        ;;
    *)
        build_and_run_ftp_server
        ;;
esac

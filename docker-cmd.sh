#!/usr/bin/env bash
# File    : docker_project_manager.sh
# Brief   : Script to manage the docker image and container for this project
# Author  : Martin Rizzo | <martinrizzo@gmail.com>
# Date    : Feb 6, 2024
# Repo    : https://github.com/martin-rizzo/QuickFtpServer
# License : MIT
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                             QuickFtpServer
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
PROJECT_DIR=$(realpath $(dirname "${BASH_SOURCE[0]}") )
IMAGE_NAME='quick-ftp-server'
IMAGE_VER='0.1'
CONTAINER_NAME='ftp-server'
CONTAINER_PARAMETERS="
    -e USER_ID=$(id -u) -e GROUP_ID=$(id -g)
    -v {DIR_TO_MOUNT}:/app:Z
    -p 20:20
    -p 21:21
    -p 21000-21007:21000-21007
"
LOG_LEVEL='debug'  # | debug | info | warn | error | fatal |

#-------------------------------- HELPERS ----------------------------------#

RED='\e[1;31m'
GREEN='\e[1;32m' 
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
DEFAULT_COLOR='\e[0m'


message() {
    echo -e "${GREEN}>${DEFAULT_COLOR} $1"
}

# Displays a warning message
warning() {
    local message=$1
    echo -e "${YELLOW}WARNING:${DEFAULT_COLOR} $message"
}

# Displays an error message
error() {
    local message=$1
    echo -e "${RED}ERROR:${DEFAULT_COLOR} $message"
}

# Displays a fatal error message and exits the script with status code 1
fatal_error() {
    local error_message=$1 extra_info=$2
    [[ -n $error_message ]] && error "$error_message"
    [[ -n $extra_info    ]] && message "$extra_info"
    exit 1
}

# Checks if a Docker container is running
docker_container_is_running() {
    local status=$(docker container inspect --format='{{.State.Status}}' "$1" 2>/dev/null)
    [[ $status = 'running' ]]
}

# Checks if a Docker container is stopped
docker_container_is_stopped() {
    local status=$(docker container inspect --format='{{.State.Status}}' "$1" 2>/dev/null)
    [[ $status = 'exited' ]]
}

# Checks if a Docker image exists in the repository
docker_image_exists() {
    docker image inspect "$1" &> /dev/null
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

    # if the image already exists then do nothing
    if docker_image_exists $IMAGE_NAME ; then
        warning "The image is already built, nothing to do."
        exit 0
    fi

    # build the Docker image
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

run_container() {
    local dir_to_mount=$1

    # before running the container again, it needs to be removed
    remove_container

    # if the image does not exist, then build it from scratch
    if ! docker_image_exists $IMAGE_NAME ; then
        build_image
    fi

    # start a new container with specified parameters
    message "Starting the '$CONTAINER_NAME' container..."
    local parameters=${CONTAINER_PARAMETERS//'{DIR_TO_MOUNT}'/$dir_to_mount}
    message "docker --log-level=$LOG_LEVEL run $parameters    --name '$CONTAINER_NAME' '$IMAGE_NAME'"
    docker "--log-level=$LOG_LEVEL" run $parameters --name "$CONTAINER_NAME" "$IMAGE_NAME"
}

# Run the container using the requested example directory
run_example() {
    local example_number=${1:-1}
    if [[ ! $example_number =~ ^[1-9]$ ]]; then
        fatal_error "Example number must be between 1 and 9"
    fi
    
    # validate the existence of the directory containing the example
    example_dir="${PROJECT_DIR}/example${example_number}"
    if [[ ! -d $example_dir ]]; then
        #fatal_error "The requested example ('./example${example_number}') has not been implemented"
        fatal_error "The requested example '$example_number' is not available" \
            "Please verify that the example is implemented in the directory './example${example_number}'"
    fi
    
    run_container "$example_dir"
}

# Stop the container if it's currently running
stop_container() {
    if docker_container_is_running $CONTAINER_NAME ; then
        message "Stopping the '$CONTAINER_NAME' container..."
        docker stop $CONTAINER_NAME 1> /dev/null && \
          message "The '$CONTAINER_NAME' container has been successfully stopped."
    fi
}

# Stop and remove the container if it exists
remove_container() {
    stop_container
    if docker_container_exists $CONTAINER_NAME ; then
        message "Removing the '$CONTAINER_NAME' container..."
        docker rm $CONTAINER_NAME 1> /dev/null && \
          message "The '$CONTAINER_NAME' container has been successfully removed."
    fi
}

restart_container() {
    stop_container && run_container
}

open_console_in_container() {
    docker exec -it "$CONTAINER_NAME" /bin/sh -l
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

#===========================================================================#
# ///////////////////////////////// MAIN ////////////////////////////////// #
#===========================================================================#

HELP="
Usage: ./docker-cmd.sh [OPTIONS] COMMAND

A script to manage the Docker image and container for this project.

Options:
  -h, --help     Display this help message and exit
  -v, --version  Display version information and exit

Commands:
  build            Build the Docker image
  clean            Clear Docker resources
  list             List Docker information
  run              Run the Docker container (equivalent to 'example1')
  test<number>     Alias for 'example<number>'
  example<number>  Run the example specified by <number>
  stop             Stop the Docker container
  restart          Restart the Docker container
  console          Open a console in the Docker container
  logs             Show Docker container logs
  exec             Execute a command in the Docker container
  status           Show the status of the Docker container
"

# check if the user requested help or the image version
if [ $# -eq 0 ]; then
    echo "$HELP" ; exit 0
fi
for param in "$@"; do
    case "$param" in
        -h|--help)
            echo "$HELP" ; exit 0
            ;;
        -v|--version)
            echo $IMAGE_NAME $IMAGE_VER
            exit 0
            ;;
        -*)
            fatal_error "Option '$param' is not supported"
            ;;
    esac
done

# process each command requested by the user
cd src
while [[ $# -gt 0 ]]; do

    param=$1
    case "$param" in
        build)
            build_image
            ;;
        clean)
            clear_docker_resources
            ;;
        run)
            run_example 1
            ;;
        test*)
            if [[ $param != 'test' ]]; then
                run_example "${param#test}"
            elif [[ $# -gt 1 ]]; then
                run_example "$2" ; shift
            else
                fatal_error "A test number is required after the 'test' command."
            fi
            ;;
        example*)
            if [[ $param != 'example' ]]; then
                run_example "${param#example}"
            elif [[ $# -gt 1 ]]; then
                run_example "$2" ; shift
            else
                fatal_error "A example number is required after the 'example' command."
            fi
            ;;
        stop)
            stop_container
            ;;
        remove)
            remove_container
            ;;
        restart)
            restart_container
            ;;
        console)
            open_console_in_container
            ;;
        list)
            list_docker_info
            ;;
        logs)
            show_container_logs
            ;;
        exec)
            execute_command_in_container
            ;;
        status)
            show_container_status
            ;;
            
        image-exists)
            docker_image_exists $IMAGE_NAME && echo YES || echo NO
            ;;
        container-exists)
            docker_container_exists $CONTAINER_NAME && echo YES || echo NO
            ;;
        is-running)
            docker_container_is_running $CONTAINER_NAME && echo YES || echo NO
            ;;
        is-stopped)
            docker_container_is_stopped $CONTAINER_NAME && echo YES || echo NO
            ;;
        *)
            fatal_error "Unknown command '$param'"
            ;;
    esac
    shift
    
done

#!/bin/sh
# File    : entrypoint.sh
# Brief   : Entry point script for QuickFtpServer
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
#
#  # HOST FIREWALL
#  firewall-cmd 'create' ftp-pasv
#  firewall-cmd 'add ports' ftp-pasv 21000-21007/tcp --permanent
#  firewall-cmd --add-service=ftp-pasv --permanent
#_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _


# CONSTANTS
PROJECT_NAME=QuickFtpServer
CONFIG_NAME=ftp.config
MAIN_USER=q-ftp
ANON_VIRTUAL_USER=ftp
QFTP_USER_TAG=__QFTP-USER__

# MAIN USER
USER_ID="${USER_ID:-$(id -u)}"
GROUP_ID="${GROUP_ID:-$(id -g)}"
USER_NAME=${USER_NAME:-$MAIN_USER}
GROUP_NAME=${GROUP_NAME:-$MAIN_USER}

# DIRECTORIES
VSFTPD_CONF_DIR=/etc/vsftpd
APPDATA_DIR=/appdata
RUN_DIR=/run
VIRTUAL_USERS_DIR=/home
LOG_DIR="$APPDATA_DIR/${LOG_DIR:-log}"
DEFAULT_HOME_DIR="$APPDATA_DIR/ftp-data"
SCRIPT_DIR=$(dirname "$0")

# FILES
QFTP_CONFIG_FILE="$APPDATA_DIR/$CONFIG_NAME"
QFTP_LOG_FILE="$LOG_DIR/quickftpserver.log"
VSFTPD_CONF_FILE="$VSFTPD_CONF_DIR/vsftpd.conf"
VSFTPD_LOG_FILE="$LOG_DIR/vsftpd.log"
PID_FILE="$RUN_DIR/vsftpd.pid"
TEMP_FILE=$(mktemp /tmp/tempfile.XXXXXX)

# CONFIG VARS
CFG_ANON=
CFG_ANON_ENABLED=NO
CFG_USER_LIST=
CFG_RESOURCE_LIST=
CFG_PASV=NO


#---------------------------- CONSOLE MESSAGES -----------------------------#

RED='\e[1;31m'
GREEN='\e[1;32m' 
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
DEFAULT_COLOR='\e[0m'
PADDING='  '

# Displays a message
function message() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${PADDING}${GREEN}>${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays a warning message
function warning() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${PADDING}${YELLOW}WARNING:${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - WARNING: $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays an error message
function error() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${PADDING}${RED}ERROR:${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - ERROR: $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays a fatal error message and exits the script with status code 1
function fatal_error() {
    local error_message=$1 info_message=$2
    error "$error_message"
    [[ -n "$info_message" ]] && message "$info_message"
    exit 1
}


#-------------------------------- HELPERS ----------------------------------#

# Validates if a string represents an integer number.
function validate_integer() {
  [[ $1 =~ ^[0-9]+$ ]]
}

function run_as_user() {
    local command=$1
    su -s /bin/sh -pc "$command" - $USER_NAME
}

# Replace placeholders in a template with corresponding values and print the resulting string.
#
# Usage:
#   print_template <template> [var1] [value1] [var2] [value2] ...
#   print_template <template> "${template_vars[@]}"
#
# Parameters:
#   - template          : the template string containing placeholders to be replaced.
#   - var1, value1, ... : pairs of variables and values to replace in the template.
#   - template_vars     : an array containing pairs of variables and values to replace in the template.
#
# Example:
#   template_vars=( "{NAME}" "John" "{DAY}" "Monday" )
#   print_template "Hello, {NAME}! Today is {DAY}" "${template_vars[@]}"
#
function print_template() {
    local template=$1 ; shift
    while [[ $# -gt 0 ]]; do
        local key=$1 value=$2
        template=${template//$key/$value}
        shift 2
    done
    echo "$template"
}

# Add a new Linux user account within the docker container.
#
# Usage:
#   add_system_user <user_name> <group_name> <home_dir> <tag>
#
# Parameters:
#   - user_name  : The desired username for the new user. If it contains a
#                  colon followed by a numerical value, it will be the numerical
#                  user ID; otherwise, the user ID will be automatically assigned.
#   - group_name : The name of the group to which the user will belong.
#   - home_dir   : The path to the user's home directory.
#   - tag        : A description or tag for the user.
#
# Example:
#   add_system_user "john_doe:1001" "developers" "/home/john_doe" __dev_tag__
#
function add_system_user() {
    local user_name=$1 group_name=$2 home_dir=$3 tag=$4
    local user_id

    # separate the username from the numeric ID (if one is provided)
    case "$user_name" in
        *':'*)
            user_id=$(echo "$user_name" | cut -d ':' -f 2)
            user_name=$(echo "$user_name" | cut -d ':' -f 1)
            ;;
    esac
    
    # check if the username already exists in the system (must be unique)
    id "$user_name" &>/dev/null && \
        fatal_error "Unable to create user '$user_name', as that name is already in use by the system" \
                    "Please choose a different name"
    
    # add the new user to the system with the specified options
    if [[ -n "$user_id" ]]; then
        adduser "$user_name" -D -H -G "$group_name" -h "$home_dir" -g "$tag" -s /sbin/nologin --uid "$user_id"
    else
        adduser "$user_name" -D -H -G "$group_name" -h "$home_dir" -g "$tag" -s /sbin/nologin
    fi
}

function ensure_system_user_and_group() {

    # validate that USER_ID and GROUP_ID are integer values
    if ! validate_integer "$USER_ID" ; then
        fatal_error "USER_ID debe ser un valor entero"
    fi
    if ! validate_integer "$GROUP_ID" ; then
        fatal_error "GROUP_ID debe ser un valor entero"
    fi
    
    # create USER_ID and GROUP_ID if they don't exist
    if ! getent group $GROUP_ID $>/dev/null; then
        message "Creating system group : $GROUP_NAME [$GROUP_ID]"
        addgroup $GROUP_NAME -g $GROUP_ID
    else
        GROUP_NAME=$(getent group $GROUP_ID | cut -d: -f1)
    fi
    if ! getent passwd "$USER_ID" &>/dev/null; then
        message "Creating system user  : $USER_NAME [$USER_ID]"
        add_system_user "$USER_NAME:$USER_ID" "$GROUP_NAME" "$DEFAULT_HOME_DIR" "QuickFtpServer"
    else
        USER_NAME=$(getent passwd $user_id | cut -d: -f1)
    fi
}

# Set the logfile for QuickFtpServer.
#
# Usage:
#   set_qftp_logfile <logfile>
#
# Parameters:
#   - logfile: the path of the log file to be set.
#
# Example:
#   set_qftp_logfile '/appdata/log/quickftpserver.log'
#
function set_qftp_logfile() {
    local logfile=$1
    [[ -z "$logfile" ]] && fatal_error "set_qftp_logfile() requires a parameter with the filename"

    # create necessary directory for log files
    if [[ ! -d $LOG_DIR ]]; then
        message "Creating directory for log files: $LOG_DIR"
        run_as_user "mkdir -p \"$LOG_DIR\""
    fi

    # create QuickFtpServer's own log file
    QFTP_LOG_FILE="$logfile"
    if [[ ! -e $QFTP_LOG_FILE ]]; then
        run_as_user "touch \"$QFTP_LOG_FILE\""
        message "Log file created: $QFTP_LOG_FILE"
    fi
}

# Create the vsftpd configuration file from the template.
#
# Usage:
#   create_vsftpd_conf <output_file> [template_file]
#
# Parameters:
#   - output_file: the path to the vsftpd configuration file to be created.
#
# Example:
#   create_vsftpd_conf "/etc/vsftpd.conf"
#
function create_vsftpd_conf() {
    local output_file=$1 template_file=${2:-'vsftpd.conf.template'}
    [[ -z   "$output_file"   ]] && fatal_error "create_vsftpd_conf() requires a parameter with the output file"
    [[ ! -f "$template_file" ]] && fatal_error "create_vsftpd_conf() requires the file $PWD/$template_file"
    
    print_template "$(cat "$template_file")"                         \
        "{MAIN_USER_NAME}"  "$USER_NAME"                             \
        "{MAIN_GROUP_NAME}" "$GROUP_NAME"                            \
        "{VSFTPD_LOG_FILE}" "$VSFTPD_LOG_FILE"                       \
        "{ANON_ENABLED}"    "$CFG_ANON_ENABLED"                      \
        "{ANON_HOME}"       "/$VIRTUAL_USERS_DIR/$ANON_VIRTUAL_USER" \
        > "$output_file"
}

#---------------------------------- USERS ----------------------------------#

# Create virtual FTP users and associate them with specified resources.
#
# Usage:
#   create_virtual_user <user_name> <user_pass> <user_resources> <resource_list> [options]
#
# Parameters:
#   - user_name      : Username for the virtual FTP user.
#   - user_pass      : Password for the virtual FTP user.
#   - user_resources : Comma-separated list of resources to associate with the user.
#   - resource_list  : List of available resources. Each line should be formatted as
#                      "resname|resdir|text"
#   - options        : Comma-separated list of options for additional configurations.
#
# Example:
#   create_virtual_user "john" "pass123" "res1,res2" "$RESOURCE_LIST" sys_user,force_readonly_dir
#
# Notes:
#   - If 'sys_user' option is provided, the script will create a system user with the given
#     username and password.
#   - If 'force_readonly_dir' option is provided, the user's home directory will be set as read-only.
#   - Each resource specified in 'user_resources' should be present in the 'resource_list'.
#   - Each virtual user can only be associated with one resource. If a user is assigned multiple
#     resources, an error will be generated.
#   - Ensure proper permissions are set on resource directories to prevent unauthorized access.
#
function create_virtual_user() {
    local user_name=$1 user_pass=$2 user_resources=$3 resource_list=$4 options=$5
    local chpasswd_message resource_values resdir home_dir

    IFS=',' ; for opt in $options; do
        case $opt in
        
            # create user and set password
            sys_user)
                add_system_user "$user_name" "$GROUP_NAME" "$DEFAULT_HOME_DIR" "$QFTP_USER_TAG"
                chpasswd_message=$(echo "$user_name:$user_pass" | chpasswd 2>&1)
                echo "      - $chpasswd_message"
                ;;
            
            # debera forzar a que el home directory sea read-only
            force_readonly_dir)
                force_readonly_dir=true
                ;;
                
        esac
    done
    
    IFS=',' ; for resource in $user_resources; do
    
        # get resource info
        resource_values=$(find_config_values "$resource" "$resource_list")
        [[ -z "$resource_values" ]] && \
            fatal_error "Resource '$resource' was not defined" \
                        "Please review the $CONFIG_NAME file"
        resdir=$(echo "$resource_values" | cut -d '|' -f 2)
        [[ -z "$resdir" ]] && \
            fatal_error "Resource '$resource' does not have an associated directory" \
                        "Please review the $CONFIG_NAME file"
            
        # define the home directory for the user based on the resource directory
        home_dir="$APPDATA_DIR/$resdir"
        [[ ! -d "$home_dir" ]] && \
            fatal_error "Directory '$resdir' associated with resource '$resource' does not exist." \
                        "Please review the $CONFIG_NAME file."

        [[ -e "/$VIRTUAL_USERS_DIR/$user_name" ]] && \
            fatal_error "El usuario '$user_name' tiene mas de un recurso asignado" \
                        "Please review the $CONFIG_NAME file."

        # link the user's home directory
        ln -s "$home_dir" "/$VIRTUAL_USERS_DIR/$user_name"
        # sudo -u otheruser test -w /file/to/test || {
        #  echo "otheruser cannot write the file"
        # }        

    done
}

# Create QuickFtpServer users based on the provided user list.
# (users are created as system users to be read by vsftpd via PAM)
#
# Usage:
#   create_qftp_users <user_list> <resource_list>
#
# Parameters:
#   - user_list     : List of users to be created. Each line should be formatted as
#                     "username|password|resource"
#   - resource_list : List of available resources. Each line should be formatted as
#                     "resname|resdir|text".
# Example:
#   create_qftp_users "$CFG_USER_LIST" "$CFG_RESOURCE_LIST"
#
# Notes:
#   - If a user already exists in the system, an error will be generated.
#   - All created users can be removed with the function remove_all_qftp_users.
#
function create_qftp_users() {
    local user_list=$1 resource_list=$2
    
    # iterate over each line of the user list
    echo "$user_list" > $TEMP_FILE
    while IFS='|' read -r user_name user_pass user_resources;
    do
    
        # skip if the username is empty
        [[ -z "$user_name" ]] && continue

        # create the virtual user and associate it with its resources
        # (the 'ftp' user is the anonymous user and doesn't need a system user)
        if [[ "$user_name" == ftp ]]; then
            create_virtual_user "$user_name" "$user_pass" "$user_resources" "$resource_list"
        else
            create_virtual_user "$user_name" "$user_pass" "$user_resources" "$resource_list" sys_user
        fi
        
    done < $TEMP_FILE
    rm $TEMP_FILE
}

# Remove all QuickFtpServer users from the system.
#
# Usage:
#   remove_all_qftp_users
#
# Description:
#   This function removes all users previously created for vsftpd.
#   It searches for users with the specified tag in the '/etc/passwd'
#   file and removes them.
#
# Example:
#   remove_all_qftp_users
#
function remove_all_qftp_users() {
    local qftp_users=$(grep "$QFTP_USER_TAG" /etc/passwd)
    
    # iterate over each linux user entry
    echo "$qftp_users" | \
    while IFS=':' read -r name pass uid gid gecos home shell
    do
        # check if the user entry matches the qftp user tag
        if [[ "$gecos" == "$QFTP_USER_TAG" ]]; then
            message "Removing old user: $name"
            deluser "$name" $>/dev/null
        fi
    done
}

#--------------------------- CONTROLLING VSFTPD ----------------------------#

function start_vsftpd() {
    local conf_file=$1
    [[ -z "$conf_file" ]] && fatal_error \
    "start_vsftpd() requires a parameter with the configuration filename"
    
    message "Launching vsftpd server"
    vsftpd "$conf_file" &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    wait "$pid" && exit $?
}

function stop_vsftpd() {
    local pid=$(cat "$PID_FILE")
    echo " * Stopping vsftpd [$pid]"
    kill -SIGTERM "$pid"
    wait "$pid"
    echo " * vsftp stopped"
}


#-------------------------- READING CONFIGURATION --------------------------#

function process_config_var() {
    local varname=$1 value=$2
    local ERROR=1
    
    case $varname in
        RESOURCE)
            value=$(format_value "$value" name dir txt) || return $ERROR
            CFG_RESOURCE_LIST="${CFG_RESOURCE_LIST}${value}$NEWLINE"
            ;;
        USER)
            value=$(format_value "$value" user pass reslist) || return $ERROR
            case "$value" in
                ftp\|*)
                    CFG_ANON=$value
                    CFG_ANON_ENABLED=YES
                    CFG_USER_LIST="${CFG_USER_LIST}${value}$NEWLINE"
                    ;;
                *)
                    CFG_USER_LIST="${CFG_USER_LIST}${value}$NEWLINE"
                    ;;
            esac
            ;;
        PASV)
            value=$(format_value "$value" bool) || return $ERROR
            CFG_PASV=$value
            ;;
        PRINT_ERROR)
            echo "ERROR: $value"
            ;;
    esac
}


#===========================================================================#
# ///////////////////////////////// MAIN ////////////////////////////////// #
#===========================================================================#


# load the configuration reader module
source "$SCRIPT_DIR/configreader.sh"  

echo
echo "$0"

message "Ensuring existence of system user/group [$USER_ID/$GROUP_ID]"
ensure_system_user_and_group

message "Activating the log file for this script: $QFTP_LOG_FILE"
set_qftp_logfile "$QFTP_LOG_FILE"

message "Switching to the script's directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR"

message "Removing any previous vsftpd configurations"
rm -f "$VSFTPD_CONF_DIR/*"
rm -f "/$VIRTUAL_USERS_DIR/*"
remove_all_qftp_users

message "Reading configuration file: $QFTP_CONFIG_FILE"
for_each_config_var_in "$QFTP_CONFIG_FILE" process_config_var

message "Creating vsftpd configuration file: $VSFTPD_CONF_FILE"
create_vsftpd_conf "$VSFTPD_CONF_FILE"

message "Creating Linux users"
create_qftp_users "$CFG_USER_LIST" "$CFG_RESOURCE_LIST"

message "Starting FTP service"
trap stop_vsftpd SIGINT SIGTERM
start_vsftpd "$VSFTPD_CONF_FILE"


# hack
chown $USER_NAME:$GROUP_NAME "$VSFTPD_LOG_FILE"
chown $USER_NAME:$GORUP_NAME "$QFTP_LOG_FILE"

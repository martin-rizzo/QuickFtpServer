#!/bin/sh

## HOST
# setsebool -P ftpd_full_access on
# firewall-cmd 'create' ftp-pasv
# firewall-cmd 'add ports' ftp-pasv 21000-21007/tcp --permanent

## CONTAINER
# /app/ftp-data
# /app/ftp-logs
# /app/ftp.config

USER_ID="${USER_ID:-$(id -u)}"
GROUP_ID="${GROUP_ID:-$(id -g)}"
USER_NAME=${USER_NAME:-'q-ftp'}
GROUP_NAME=${GROUP_NAME:-'q-ftp'}

# DIRECTORIES
VSFTPD_CONF_DIR=/etc/vsftpd
APPDATA_DIR=/app
RUN_DIR=/run
LOG_DIR="$APPDATA_DIR/${LOG_DIR:-log}"
HOME_DIR="$APPDATA_DIR/${HOME_DIR:-ftp-data}"
SCRIPT_DIR=$(dirname "$0")

# FILES
PID_FILE="$RUN_DIR/vsftpd.pid"
VSFTPD_CONF_FILE="$VSFTPD_CONF_DIR/vsftpd.conf"
VSFTPD_USERS_DB="$VSFTPD_CONF_DIR/virtual-users.db"
VSFTPD_LOG_FILE="$LOG_DIR/vsftpd.log"

QFTP_LOG_FILE="$LOG_DIR/quickftpserver.log"
QFTP_CONFIG_FILE="$APPDATA_DIR/ftp.config"
QFTP_USER_TAG="__QFTP-USER__"

#-------------------------------- HELPERS ----------------------------------#

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
    local message=$1
    error "$message"
    exit 1
}

# Validates if a string represents an integer number.
validate_integer() {
  [[ $1 =~ ^[0-9]+$ ]]
}

run_as_user() {
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



#vsftpd /etc/vsftpd/vsftpd.conf -xferlog_enable=YES -vsftpd_log_file=$(tty)

#vsftpd -xferlog_enable=YES -vsftpd_log_file=$(tty)


ensure_system_user_and_group() {

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
        adduser $USER_NAME -G $GROUP_NAME -g "QuickFtpServer" -h "$HOME_DIR" -s /sbin/nologin -D -H --uid $USER_ID
    else
        USER_NAME=$(getent passwd $user_id | cut -d: -f1)
    fi
    mkdir -p "$HOME_DIR"
    #chown "$USER_NAME:$GROUP_NAME" "$HOME_DIR"
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
    
    print_template "$(cat "$template_file")"    \
        "{USER_NAME}"       "$USER_NAME"        \
        "{GROUP_NAME}"      "$GROUP_NAME"       \
        "{VSFTPD_LOG_FILE}" "$VSFTPD_LOG_FILE"  \
        > "$output_file"
}

#---------------------------------- USERS ----------------------------------#

# Create vsftpd users based on the provided user list.
#
# Usage:
#   create_vsftpd_users <user_list>
#
# Parameters:
#   - user_list: List of users to be created, each line
#                formatted as "username|password|resource".
# Example:
#   create_vsftpd_users "$CFG_USER_LIST"
#
# Notes:
#   - Each line in 'user_list' should be "username|password|resource".
#   - The resource field is optional and can be left empty.
#   - If a user already exists in the system, an error will be generated.
#
function create_vsftpd_users() {
    local user_list=$2    
    local chpasswd_message
    
    message "Creating Linux users"
    echo "$user_list" | while IFS='|' read -r name pass resource;
    do
        # skip if the username is empty
        [[ -z "$name" ]] && continue
        
        # check if the username already exists in the system (must be unique)
        id "$name" &>/dev/null  && \
            fatal_error "Unable to create user '$name', that name is already in use by the system" \
                        "Please choose a different name"
        
        # create user and set password
        adduser -D -H -g "$QFTP_USER_TAG" "$name" &>/dev/null
        chpasswd_message=$(echo "$name:$pass" | chpasswd 2>&1)
        echo "      - $chpasswd_message"
    done
}

# Remove all vsftpd users from the system.
#
# Usage:
#   remove_all_vsftpd_users
#
# Description:
#   This function removes all users previously created for vsftpd.
#   It searches for users with the specified tag in the '/etc/passwd'
#   file and removes them.
#
# Example:
#   remove_all_vsftpd_users
#
# Requires:
#   - $QFTP_USER_TAG: variable specifying the tag used to identify users.
#
function remove_all_vsftpd_users() {
    local vsftpd_users=$(grep "$QFTP_USER_TAG" /etc/passwd)
    
    # iterate over each linux user entry
    echo "$vsftpd_users" | \
    while IFS=':' read -r name pass uid gid gecos home shell
    do
        # check if the user entry matches the vsftpd user tag
        if [[ "$gecos" == "$QFTP_USER_TAG" ]]; then
            message "Removing old user: $name"
            deluser "$name" $>/dev/null
        fi
    done
}

#-------------------------- READING CONFIGURATION --------------------------#

function process_config_var() {
    local varname=$1 value=$2
    local ERROR=1
    
    case $varname in
        RESOURCE)
            value=$(format_value "$value" name dir txt) || return $ERROR
            CFG_RESOURCES="${CFG_RESOURCES}${value}$NEWLINE"
            ;;
        USER)
            value=$(format_value "$value" user pass name) || return $ERROR
            CFG_USER_LIST="${CFG_USER_LIST}${value}$NEWLINE"
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




function start_vsftpd() {
    local conf_file=$1
    [[ -z "$conf_file" ]] && fatal_error \
    "start_vsftpd() requires a parameter with the configuration filename"
    
    message  "Setting FTP directory permissions to read-only"
    chmod u-w "$HOME_DIR"
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
    echo " * making ftp directory writtable"
    chmod u+x "$HOME_DIR"
}





#===========================================================================#
# ///////////////////////////////// MAIN ////////////////////////////////// #
#===========================================================================#


# load the configuration reader module
source "$SCRIPT_DIR/configreader.sh"  

echo
echo "$0"

# ensure that system user and group exist (USER_ID/GROUP_ID)
message "Ensuring existence of system user/group [$USER_ID/$GROUP_ID]"
ensure_system_user_and_group

# activate log file for QuickFtpServer
message "Outputting log from this script to: $QFTP_LOG_FILE"
set_qftp_logfile "$QFTP_LOG_FILE"

# change to the directory of the current script
message "Switching to the script's directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR"


# elimina cualquier antigua configuracion de vsdftpd que haya quedado
message "Reiniciando la configuración de vsftpd"
rm -f "$VSFTPD_CONF_DIR/*"
remove_all_vsftpd_users

# carga la configuracion del usuario
message "Cargando configuracion del usuario: $QFTP_CONFIG_FILE"
for_each_config_var_in "$QFTP_CONFIG_FILE" process_config_var

# create configuration file for vsftpd
message "Creating configuration file: $VSFTPD_CONF_FILE"
create_vsftpd_conf "$VSFTPD_CONF_FILE"

create_vsftpd_users "$VSFTPD_USERS_DB" "$CFG_USER_LIST"

# start the vsftpd server as a service.
message "Starting FTP service"
trap stop_vsftpd SIGINT SIGTERM
start_vsftpd "$VSFTPD_CONF_FILE"


# hack
chown $USER_NAME:$GROUP_NAME "$VSFTPD_LOG_FILE"
chown $USER_NAME:$GORUP_NAME "$QFTP_LOG_FILE"

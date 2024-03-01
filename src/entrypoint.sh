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
HOME_DIR=${HOME_DIR:-'ftp-data'}
LOG_DIR=${LOG_DIR:-'log'}

APP_DIR=/app
PID_FILE=/var/run/vsftpd.pid
HOME_DIR="$APP_DIR/$HOME_DIR"
LOG_DIR="$APP_DIR/$LOG_DIR"
VSFTPD_CONF_FILE=/etc/vsftpd/vsftpd.conf


#-------------------------------- HELPERS ----------------------------------#

RED='\e[1;31m'
GREEN='\e[1;32m' 
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
DEFAULT_COLOR='\e[0m'

# Displays a message
function message() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}>${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays a warning message
function warning() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}WARNING:${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - WARNING: $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays an error message
function error() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}ERROR:${DEFAULT_COLOR} $message"
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


ensure_main_user_and_group() {

    # validate that USER_ID and GROUP_ID are integer values
    if ! validate_integer "$USER_ID" ; then
        fatal_error "USER_ID debe ser un valor entero"
    fi
    if ! validate_integer "$GROUP_ID" ; then
        fatal_error "GROUP_ID debe ser un valor entero"
    fi
    
    # create USER_ID and GROUP_ID if they don't exist
    if ! getent group $GROUP_ID $>/dev/null; then
        message "Creating group $GROUP_NAME [$GROUP_ID]"
        addgroup $GROUP_NAME -g $GROUP_ID
    else
        GROUP_NAME=$(getent group $GROUP_ID | cut -d: -f1)
    fi
    if ! getent passwd "$USER_ID" &>/dev/null; then
        message "Creating user $USER_NAME [$USER_ID]"
        adduser $USER_NAME -G $GROUP_NAME -g "Simple FTP Server" -h "$HOME_DIR" -s /sbin/nologin -D -H --uid $USER_ID
    else
        USER_NAME=$(getent passwd $user_id | cut -d: -f1)
    fi
    mkdir -p "$HOME_DIR"
    #chown "$USER_NAME:$GROUP_NAME" "$HOME_DIR"
}

# Set the logfile for QuickFtpServer.
#
# Usage:
#   set_qftp_logfile <logfile_name>
#
# Parameters:
#   - logfile_name: the name of the log file to be set.
#
# Example:
#   set_qftp_logfile 'quickftpserver.log'
#
function set_qftp_logfile() {
    local logfile_name=$1
    [[ -z "$logfile_name" ]] && fatal_error "set_qftp_logfile() requires a parameter with the filename"

    # create necessary directory for log files
    if [[ ! -d $LOG_DIR ]]; then
        message "Creating directory for log files: $LOG_DIR"
        run_as_user "mkdir -p \"$LOG_DIR\""
    fi

    # create QuickFtpServer's own log file
    QFTP_LOG_FILE="$LOG_DIR/$logfile_name"
    if [[ ! -e $QFTP_LOG_FILE ]]; then
        run_as_user "touch \"$QFTP_LOG_FILE\""
        message "Log file created: $QFTP_LOG_FILE"
    fi
}

# Create the vsftpd configuration file from the template.
#
# Usage:
#   create_vsftpd_conf <conf_path>
#
# Parameters:
#   - conf_path: the path to the vsftpd configuration file to be created.
#                (the template file name will be "${conf_path}.template")
# Example:
#   create_vsftpd_conf "/etc/vsftpd.conf"
#
function create_vsftpd_conf() {
    local conf_path=$1
    local template_path="${conf_path}.template"
    [[ -z   "$conf_path"     ]] && fatal_error "create_vsftpd_conf() requires a parameter with the filepath"
    [[ ! -f "$template_path" ]] && fatal_error "create_vsftpd_conf() requires the file $template_path"
    
    print_template "$(cat "$template_path")" \
        "{USER_NAME}"   "$USER_NAME"         \
        "{GROUP_NAME}"  "$GROUP_NAME"        \
        > "$conf_path"
}



function start_service() {
    local pid
    message "Making ftp directory read-only"
    chmod u-w "$HOME_DIR"
    message "Starting vsftpd"
    vsftpd "$VSFTPD_CONF_FILE" &
    pid=$!
    echo "$pid" > "$PID_FILE"
    wait "$pid" && exit $?
}

function stop_service() {
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

# ensure that the requested USER_ID and GROUP_ID exist.
ensure_main_user_and_group

# activa el archivo de log para QuickFtpServer
set_qftp_logfile 'quickftpserver.log'

# crear el archivo de configuracion para vsftpd
create_vsftpd_conf "$VSFTPD_CONF_FILE"

# start the vsftpd server as a service.
trap stop_service SIGINT SIGTERM
start_service

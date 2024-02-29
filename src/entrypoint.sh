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
message() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}>${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays a warning message
warning() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}WARNING:${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - WARNING: $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays an error message
error() {
    local message=$1 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}ERROR:${DEFAULT_COLOR} $message"
    if [[ -n "$QFTP_LOG_FILE" ]]; then
        echo "$timestamp - ERROR: $message" >> "$QFTP_LOG_FILE"
    fi
}

# Displays a fatal error message and exits the script with status code 1
fatal_error() {
    local message=$1
    error "$message"
    exit 1
}

# Validates if a string represents an integer number.
validate_integer() {
  [[ $1 =~ ^[0-9]+$ ]]
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

ensure_qftp_logfile() {

    # create necessary directory for log files
    if [[ ! -d $LOG_DIR ]]; then
        message "Creating directory for log files: $LOG_DIR"
        run_as_user "mkdir -p \"$LOG_DIR\""
    fi

    # create QuickFtpServer's own log file
    QFTP_LOG_FILE="$LOG_DIR/quickftpserver.log"
    if [[ ! -e $QFTP_LOG_FILE ]]; then
        run_as_user "touch \"$QFTP_LOG_FILE\""
        message "Log file created: $QFTP_LOG_FILE"
    fi
}

add_virtual_user() {
    echo not implemented
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



run_as_user() {
    local command=$1
    su -s /bin/sh -pc "$command" - $USER_NAME
}


#===========================================================================#
# ///////////////////////////////// MAIN ////////////////////////////////// #
#===========================================================================#

# ensure that the requested USER_ID and GROUP_ID exist.
ensure_main_user_and_group

# ensure that the QuickFtpServer log file exists.
ensure_qftp_logfile

# start the vsftpd server as a service.
trap stop_service SIGINT SIGTERM
start_service

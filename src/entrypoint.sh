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
USER_NAME=
GROUP_ID="${GROUP_ID:-$(id -g)}"
GROUP_NAME=
FTP_DATA_DIR='ftp-data'

APP_DIR=/app
PID_FILE=/var/run/vsftpd.pid
FTP_DIR="$APP_DIR/$FTP_DATA_DIR"
VSFTPD_CONF_FILE=/etc/vsftpd/vsftpd.conf
DEFAULT_USER_NAME='s-ftp'
DEFAULT_GROUP_NAME='s-ftp'


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

# Función para validar si una cadena es un número entero
function validate_integer() {
  [[ $1 =~ ^[0-9]+$ ]]
}




#vsftpd /etc/vsftpd/vsftpd.conf -xferlog_enable=YES -vsftpd_log_file=$(tty)

#vsftpd -xferlog_enable=YES -vsftpd_log_file=$(tty)


ensure_main_user_and_group() {

    # valida que USER_ID/GROUP_ID sean numeros enteros
    if ! validate_integer "$USER_ID" ; then
        fatal_error "USER_ID debe ser un valor entero"
    fi
    if ! validate_integer "$GROUP_ID" ; then
        fatal_error "GROUP_ID debe ser un valor entero"
    fi
    
    # crea USER_ID/GROUP_ID en caso de no existir
    if ! getent group $GROUP_ID $>/dev/null; then
        GROUP_NAME=$DEFAULT_GROUP_NAME
        echo " * Creando el grupo $GROUP_NAME [$GROUP_ID]"
        addgroup $GROUP_NAME -g $GROUP_ID
    else
        GROUP_NAME=$(getent group $GROUP_ID | cut -d: -f1)
    fi
    if ! getent passwd "$USER_ID" &>/dev/null; then
        USER_NAME=$DEFAULT_USER_NAME
        echo " * Creando el usuario $USER_NAME [$USER_ID]"
        adduser $USER_NAME -G $GROUP_NAME -g "Simple FTP Server" -h "$FTP_DIR" -s /sbin/nologin -D -H --uid $USER_ID
    else
        USER_NAME=$(getent passwd $user_id | cut -d: -f1)
    fi
    mkdir -p "$FTP_DIR"
    #chown "$USER_NAME:$GROUP_NAME" "$FTP_DIR"
}

add_virtual_user() {
    echo not implemented
}


function start_service() {
    local pid
    echo " * making ftp directory read-only"
    chmod u-w "$FTP_DIR"
    echo " * Starting vsftpd"
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
    chmod u+x "$FTP_DIR"
}

# se asegura que existan el USER_ID y GROUP_ID solicitados
ensure_main_user_and_group

trap stop_service SIGINT SIGTERM
start_service

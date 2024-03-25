#!/bin/sh
# File    : test.sh
# Brief   : Example code for testing 'configreader.sh'
# Author  : Martin Rizzo | <martinrizzo@gmail.com>
# Date    : Mar 19, 2024
# Repo    : https://github.com/martin-rizzo/QuickFtpServer
# License : MIT
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
source './configreader.sh'

# possible configuration files to process
CFG_FILE1=/app/ftp.config          # <- inside the container
CFG_FILE2=../example2/ftp.config   # <- outside the container

function process_config_var() {
    local varname=$1 value=$2
    local ERROR=1
    
    case $varname in
        RESOURCE)
            value=$(format_value "$value" name dir txt) || return ERROR
            CFG_RESOURCES="${CFG_RESOURCES}${value}$NEWLINE"
            ;;
        USER)
            value=$(format_value "$value" user pass name) || return ERROR
            CFG_USERS="${CFG_USERS}${value}$NEWLINE"
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

#================================== START ==================================#

# for each variable found in 'ftp.config',
# execute the 'process_config_var' function.

if [[ -f $CFG_FILE1 ]]; then
    for_each_config_var_in "$CFG_FILE1" process_config_var
elif [[ -f $CFG_FILE2 ]]; then
    for_each_config_var_in "$CFG_FILE2" process_config_var
else
    echo "ERROR: file $CFG_FILE1 or $CFG_FILE2 does not exist"
    exit 1
fi

echo
echo RESOURCES
echo "$CFG_RESOURCES" | while IFS='|' read -r name dir desc; do
    echo "name='$name'  dir='$dir'"
done
echo
echo "$CFG_USERS" | while IFS='|' read -r name pass x; do
    echo "'$name'"
done
echo
echo PASV = $CFG_PASV

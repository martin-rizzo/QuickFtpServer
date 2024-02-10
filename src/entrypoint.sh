#!/bin/sh

echo "####" $1 "####"

#vsftpd /etc/vsftpd/vsftpd.conf -xferlog_enable=YES -vsftpd_log_file=$(tty)

#vsftpd -xferlog_enable=YES -vsftpd_log_file=$(tty)

vsftpd /etc/vsftpd/vsftpd.conf

echo "#### EXIT #####"

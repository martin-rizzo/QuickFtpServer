# File    : Dockerfile
# Brief   : Dockerfile for setting up QuickFtpServer
# Author  : Martin Rizzo | <martinrizzo@gmail.com>
# Date    : Feb 27, 2024
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

# Use Alpine Linux as the base image for lightweight containerization
FROM alpine:3.19.1

# Install vsftpd & db_load (for virtual user db)
RUN set -ex    \
 && apk update \
 && apk add --no-cache vsftpd
 # gcc libgcc linux-pam-dev

# Install the PAM file for FTP user authentication
COPY vsftpd.pam /etc/pam.d/vsftpd

# Copy project setup files to the /root directory:
#   - vsftpd.conf.template : configuration file template
#   - lib_config.sh        : configuration reader module
#   - lib_utils.sh         : utility functions module
#   - entrypoint.sh        : container startup script
WORKDIR /root
COPY vsftpd.conf.template lib_config.sh lib_utils.sh entrypoint.sh ./

# Set execute permissions for scripts
RUN chmod +x entrypoint.sh

# Expose FTP data (port 20), FTP control (port 21), PASV ports (21000-21007)
EXPOSE 20 21 21000-21007

# Adds aliases for convenience within the container, useful for CLI interaction
RUN echo "alias ll='ls -lh --group-directories-first'" > /etc/profile.d/ls_aliases.sh
RUN echo "alias ll.='ls -l -d .* --color=auto'"       >> /etc/profile.d/ls_aliases.sh

#RUN set -ex  \
# && apk del gcc libgcc \
# && apk cache purge

# Define the entry point script for container startup
ENTRYPOINT  ["/root/entrypoint.sh", "param1", "param2"]


# Use Alpine Linux as base
FROM alpine:3.19.1

# Install the FTP server (in this case, vsftpd)
RUN apk update && \
    apk add --no-cache vsftpd

# Hace un backup de los usuarios y grupos actuales
#COPY /etc/passwd /etc/passwd.original
#COPY /etc/group  /etc/group.original


# Copy the custom configuration file
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf.template


COPY configreader.sh  /configreader.sh
COPY test.sh          /test.sh
RUN chmod +x          /test.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x       /entrypoint.sh


# Adds a couple of aliases for 'll' (useful for 'docker-cmd console')
RUN echo "alias ll='ls -lh --group-directories-first'" > /etc/profile.d/ls_aliases.sh
RUN echo "alias ll.='ls -l -d .* --color=auto'"       >> /etc/profile.d/ls_aliases.sh


# Expose port 20 (FTP data) and 21 (FTP control)
EXPOSE 20 21
EXPOSE 21000-21007

# Run the FTP server when the container starts
#CMD ["envsftpd", "/etc/vsftpd/vsftpd.conf"]
ENTRYPOINT ["/entrypoint.sh", "Hello World!"]

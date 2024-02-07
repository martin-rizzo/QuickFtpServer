# Use Alpine Linux as base
FROM alpine:3.19.1

# Install the FTP server (in this case, vsftpd)
RUN apk update && \
    apk add --no-cache vsftpd

# Copy the custom configuration file
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf

# Expose port 20 (FTP data) and 21 (FTP control)
EXPOSE 20 21

# Run the FTP server when the container starts
CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]

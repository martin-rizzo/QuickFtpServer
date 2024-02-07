
# Simple FTP Server

## Description
Simple FTP Server is a lightweight and straightforward implementation of an FTP (File Transfer Protocol) server, designed to adapt to various applications. While the use of FTP has declined in modern times, it remains highly useful for accessing files from legacy systems, such as those running older versions of operating systems like Windows 3.1. By leveraging Docker container technology, this server also offers a portable solution that simplifies deployment and accommodates the diverse requirements of users.

### Key Features
- Designed for making FTP file access and sharing simple.
- Provides a functional FTP server configured to allow anonymous and local connections with write capability.
- Server configuration is done through custom configuration files, enabling easy customization according to user needs.
- Utilizes Alpine Linux as the base to minimize image size and enhance security.
- Uses a Bash script to automate Docker resource building, execution, and cleanup, simplifying server management and deployment.

## Usage
Simple FTP Server is ideal for facilitating file access and sharing on vintage systems, simplifying the process for users familiar with initiating FTP connections. It serves as a convenient solution for transferring files between modern systems and retro platforms. Additionally, it can be used for conducting file transfer tests or providing a temporary file storage service.

## Technologies Used
- **Docker**: For container creation, management, and deployment.
- **Alpine Linux**: As the base operating system to minimize image size and improve security.
- **vsftpd**: Lightweight and secure FTP server used to provide FTP service.

## Objective
The objective of Simple FTP Server is to provide a seamless solution for implementing a file server that can be accessed from vintage systems running Windows 3.1, DOS, or any retro system with an FTP client. It aims to offer easy file access and sharing capabilities, simplifying the process. By leveraging Docker containers, it streamlines the configuration and management of the FTP server without worrying about the complexities of server setup.

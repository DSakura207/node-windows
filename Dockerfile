# escape=`

# The image utilize NVM for Windows to install Node.js.
# NVM executable is saved in the container 
# to provide a convenient way 
# to switch Node.js version without pulling a new image.

# Base image name, default to Windows Server Core
ARG BASE_IMAGE_NAME=mcr.microsoft.com/windows/servercore

# Base image tag, default to 2019 LTSC
ARG BASE_IMAGE_TAG=ltsc2019

# Default image: Windows Server Core 2019 LTSC
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

# NVM version
ARG NVM_VERSION=1.1.9

# Node.js version
ARG NODE_VERSION=lts

# Node.js architecture
ARG NODE_ARCH=64

# Prepare NVM environment variables and install folder
# NVM_HOME: location of NVM
# NVM_SYMLINK: location of Node.js symbolic link
RUN `
    setx NVM_HOME "%APPDATA%\nvm" /m`
    && (mkdir %APPDATA%\nvm) `
    && (setx NVM_SYMLINK "%ProgramFiles%\nodejs" /m) `
    && (setx PATH "%PATH%;%APPDATA%\nvm;%ProgramFiles%\nodejs" /m) 

# Install NVM and create NVM config file
RUN `
    cd %NVM_HOME% `
    && (curl -SL --output nvm-noinstall.zip https://github.com/coreybutler/nvm-windows/releases/download/%NVM_VERSION%/nvm-noinstall.zip) `
    && (tar -xf nvm-noinstall.zip) `
    && (echo root: %NVM_HOME% > %NVM_HOME%\settings.txt) `
    && (echo path: %NVM_SYMLINK% >> %NVM_HOME%\settings.txt) `
    && (echo arch: %NODE_ARCH% >> %NVM_HOME%\settings.txt) `
    && (echo proxy: none >> %NVM_HOME%\settings.txt) `
    && (del /q nvm-noinstall.zip)

# Install Node.js with NVM
RUN `
    nvm install %NODE_VERSION% `
    && (nvm use %NODE_VERSION%)

COPY docker-entrypoint.cmd C:/Windows/

ENTRYPOINT [ "docker-entrypoint.cmd" ]

CMD [ "node" ]
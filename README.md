# CUPS on Docker

[![Docker](https://github.com/jelliuk/alpine-docker-cups/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/jelliuk/alpine-docker-cups/actions/workflows/docker-publish.yml) [![License](https://img.shields.io/badge/License-GNU_GPLv3-blue)](#license)

This is a Docker image to run a CUPS instance with built in Apples zeroconf support.

This Docker image is based on the offical [Debian Trixi Slim](https://hub.docker.com/_/debian/) image.

#### Table of Contents

- [Install Docker](https://github.com/jelliuk/alpine-docker-cups#install-docker)
- [Download](https://github.com/jelliuk/alpine-docker-cups#download)
- [How to use this image](https://github.com/jelliuk/alpine-docker-cups#how-to-use-this-image)
- [Next steps](https://github.com/jelliuk/alpine-docker-cups#next-steps)
- [Important notes](https://github.com/jelliuk/alpine-docker-cups#important-notes)
- [Update Docker image](https://github.com/jelliuk/alpine-docker-cups#update-docker-image)
- [Advanced usage](https://github.com/jelliuk/alpine-docker-cups#advanced-usage)
- [Technical details](https://github.com/jelliuk/alpine-docker-cups#technical-details)
- [Development](https://github.com/jelliuk/alpine-docker-cups#development)

## Install Docker

To use this image you have to [install Docker](https://docs.docker.com/engine/installation/) first.

## Download

You can get the trusted build from the [ghcr.io](https://github.com/jelliuk/alpine-docker-cups/pkgs/container/alpine-docker-cups):

```
docker pull ghcr.io/jelliuk/alpine-docker-cups:master
```

Alternatively, you may build the Docker image from the
[source code](https://github.com/jelliuk/alpine-docker-cups#build-from-source-code) on GitHub.

## How to use this image

### Environment variables

You can use two environment variables that will be recognized by the start script.

#### `CUPS_PASSWORD`

If this environment variable is set, the string will be used as the password for the `root` user.

#### `CUPS_DEBUG`

If this environment variable is set, the scripts inside the container will run in debug mode.

### Start the CUPS instance

The instance can be started by the [start script](https://raw.githubusercontent.com/jelliuk/alpine-docker-cups/master/start_cups.sh)
from GitHub:

```
wget https://raw.githubusercontent.com/jelliuk/alpine-docker-cups/master/start_cups.sh
export CUPS_PASSWORD='SeCre!1'
chmod 755 start_cups.sh
./start_cups.sh
```

### Check server status

You can use the standard Docker commands to examine the status of the CUPS instance:

```
docker logs --tail 1000 --follow --timestamps cups
```

## Next steps

The next release of this Docker image should have a persistent CUPS configuration.

## Important notes

The username for the print server is `root`/`password` unless you don't change the password with the environment
variable as described in the [Environment variables](https://github.com/jelliuk/alpine-docker-cups#how-to-use-this-image)
section.

## Update Docker image

Simply download the trusted build from the [ghcr.io](https://github.com/jelliuk/alpine-docker-cups/pkgs/container/alpine-docker-cups):

```
docker pull ghcr.io/jelliuk/alpine-docker-cups:master
```

## Advanced usage

### Build from source code

You can build the image also from source. To do this you have to clone the
[docker-cups](https://github.com/jelliuk/alpine-docker-cups/) repository from GitHub:

```
git clone https://github.com/jelliuk/alpine-docker-cups.git
cd docker-cups
docker build --rm --no-cache -t ghcr.io/jelliuk/alpine-docker-cups:master .
```

### Bash shell inside container

If you need a shell inside the container you can run the following command:

```
docker exec -ti cups /bin/sh
```

### Add network tools ###

If you need network tools to debug your installation use the following command:

```
docker exec -ti cups /bin/sh
apk update
apk add iputils iproute2
```

## Technical details

- Alpine base image
- CUPS binary from official Alpine package repository
- Samsung ML-1910.ppd for printer compatibility

## Development

Build is developed for personal use only, you're welcome to use it but due to time constraints, no user support can be provided.

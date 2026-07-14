# CUPS Docker Container 🖨️
**A robust containerized solution for running CUPS with built-in Bonjour/Avahi support.**

This image provides a fully containerized Print Services Unit (CUPS) instance, simplifying deployment on modern Linux systems. It is built upon Debian Trixie Slim and includes native support for Bonjour discovery via Avahi, along with pre-configured drivers for common professional devices like the Samsung ML-1910 and CLP325 Laser Printers.

***

### Build Status
| Branch | Status |
| --- | --- |
|Development | [![Development Build and Publish](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-development.yml/badge.svg)](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-development.yml) |
|Production | [![Production Build and Publish](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-production.yml/badge.svg)](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-production.yml)|

### 🚀 Quick Start Guide

To get a functional CUPS server running, follow these steps:

#### Step 1: Install Docker
Ensure you have [Docker](https://docs.docker.com/engine/installation/) installed on your host machine.

#### Step 2: Pull the Image
Download the latest stable build from GHCR:

```bash
docker pull ghcr.io/jelliuk/docker-cups:master
```

#### Step 3: Run the Container Instance
We recommend using a start script to initialize the environment and secure the instance before running it.

1. **Get the Start Script:**
   ```bash
   wget https://raw.githubusercontent.com/jelliuk/docker-cups/master/start_cups.sh
   chmod 755 start_cups.sh
   ```

2. **Set Environment Variables (Recommended):**
   It is strongly recommended to define an environment variable for a secure root password:
   ```bash
   export CUPS_ENV_PASSWORD='YourStrongPasswordHere!'
   # Optional: Uncomment the line below if you need immediate debug logs during startup:
   # export CUPS_ENV_DEBUG=true
   ```

3. **Execute the Script:**
   Run the initialization script to start the print server:
   ```bash
   ./start_cups.sh
   ```

***

### 🛠️ Usage & Configuration Details

#### Environment Variables Reference

The start script honors the following environment variables for initial configuration:

*   **`CUPS_ENV_PASSWORD`**: Defines the password for the `root` administrator account on the print server. **Recommendation:** Always set this to a strong, unique password to secure your deployment.
*   **`CUPS_ENV_DEBUG`**: Setting this variable (e.g., `export CUPS_ENV_DEBUG=true`) will force the startup script into an extended debug mode (`set -ex`), greatly aiding troubleshooting connectivity or configuration problems.
*   **`CUPS_ENV_HOST`**: Allows you to specify a custom hostname for the service URL, which is useful when deploying behind specific DNS records or local networks.

#### Monitoring Server Status (Logs)

You can monitor the standard output and logs of the running CUPS service using native Docker commands:

```bash
docker logs --tail 1000 --follow --timestamps cups
```

#### Health Check Verification 

The container provides its own healthcheck, this is silent within the docker logs and verifies that CUPS is active on its primary port, you can check the health status using a command similar to:

```bash
curl --fail --silent http://localhost:631/printers/
```

***

### ✨ Advanced Usage

For system administrators requiring deeper access or additional functionality:

#### Accessing a Shell Inside the Container
To manually inspect files, run diagnostics, or add network tools, execute a shell session:

```bash
docker exec -ti cups /bin/sh
```

**Debugging Network Tools:** To install essential network utilities (like `iputils` and `iproute2`) within the container environment (only requiured for debugging, etc. not required for normal functionality):

*(Run these commands after entering the container shell)*
```bash
apk update
apk add iputils iproute2
exit # Exit the container shell when done
```

#### Building from Source Code
If you require a custom build or wish to contribute changes, clone the repository and compile locally:

```bash
git clone https://github.com/jelliuk/docker-cups.git
cd docker-cups
docker build --rm --no-cache -t ghcr.io/jelliuk/docker-cups:master .
```

***

### 📝 Important Notes & Maintenance

*   **Default Credentials:** The initial print server credentials are `root` / `password`. **Always set the `CUPS_ENV_PASSWORD` environment variable to change this password.**
*   **Updating:** To pull the latest changes or patch versions, simply re-run:
    ```bash
    docker pull ghcr.io/jelliuk/docker-cups:master
    ```

### ⚙️ Technical Specifications & Networking

*   **Base Image:** Debian Trixie Slim (Optimized for stability and reduced size).
*   **Networking Ports Exposed:**
    *   `631/tcp`: Standard IPP port for printer sharing.
    *   `5353/udp`: Mandatory Multicast DNS (mDNS) / Avahi port, enabling Bonjour discovery on the local network.
*   **Dependencies:** The container includes core packages such as `cups`, `avahi-daemon`, `ghostscript`, and specialized drivers (`printer-driver-foo2zjs`, `printer-driver-splix`).
*   **Development Status:** This image is maintained for personal use only. While usage is welcomed, dedicated user support cannot be provided due to time constraints.

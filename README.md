# CUPS Docker Container 🖨️
**A robust containerized solution for running CUPS with built-in Bonjour/Avahi support.**

This image provides a fully containerized Print Services Unit (CUPS) instance, simplifying deployment on modern Linux systems. It is built upon Debian Trixie Slim and includes native support for Bonjour discovery via Avahi, along with pre-configured drivers for common professional devices like the Samsung ML-1910 and CLP-325 Laser Printers.

***

### Features
- CUPS print server
- Bonjour / AirPrint discovery via Avahi
- Built-in health checks
- Persistent configuration and printer data
- Samsung ML-1910 and CLP-325 driver support

### Build Status
| Branch | Status |
| --- | --- |
|Development | [![Development Build and Publish](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-development.yml/badge.svg)](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-development.yml) |
|Production | [![Production Build and Publish](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-production.yml/badge.svg)](https://github.com/jelliuk/docker-cups/actions/workflows/docker-build-publish-production.yml)|

Production only builds and publishes after a Development run completes successfully. See [`security-findings.md`](security-findings.md) for the current, non-blocking Trivy scan results for the most recent build.

### 🚀 Quick Start Guide

To get a functional CUPS server running, follow these steps:

#### Step 1: Requirements
Ensure you have [Docker](https://docs.docker.com/engine/installation/) and [Docker Compose](https://docs.docker.com/compose/install/) installed on your host machine.

Verify installation:
```bash
docker --version
docker compose version
```

#### Step 2: Create docker-compose.yml
Create a docker-compose.yml at the appropriate location within the host machine along with respective folders for bind-mounts (volume mounts also a valid option).

```
services:
  cups:
    image: ghcr.io/jelliuk/docker-cups:latest # use latest or pin a release
    container_name: cups
    restart: unless-stopped
    privileged: true # required for USB printers
    ports:
      - "631:631/tcp"
      - "5353:5353/udp"
    environment:
      - TZ=Europe/London
      - CUPS_ENV_PASSWORD=change_me!
    volumes:
      - /var/run/dbus:/var/run/dbus # required for USB printers
      - ./config:/etc/cups
      - ./spool:/var/spool/cups
      - ./logs:/var/log/cups
```

#### Step 3: Start the Service
Launch the container:
```bash
docker compose up -d
```
Verify it is running:
```bash
docker compose ps
```
Expected output:

| NAME | STATUS |
| --- | --- |
| cups | running (healthy) |

#### Step 4: Access the CUPS Web Interface
Open your browser and navigate to:

- ```http://<SERVER-IP>:631```

Examples:

- ```http://localhost:631```
- ```http://192.168.1.10:631```

You should now see the CUPS administration interface.

***

### 🛠️ Usage & Configuration Details

#### Environment Variables Reference

The start script honors the following environment variables for initial configuration:

*   **`CUPS_ENV_PASSWORD`**: Defines the password for the `root` administrator account on the print server. **Recommendation:** Always set this to a strong, unique password to secure your deployment.

#### Monitoring Server Status (Logs)

You can monitor the standard output and logs of the running CUPS service using native Docker commands:

```bash
docker logs --tail 1000 --follow --timestamps cups
```

#### Health Check Verification 

The container provides its own healthcheck, this is silent within the docker logs and verifies that CUPS is active on its primary port, you can check the health status using a command similar to:

```bash
curl --fail --silent http://<SERVER-IP>:631/printers/
```

***

### ✨ Advanced Usage

For system administrators requiring deeper access or additional functionality:

#### Accessing a Shell Inside the Container
To manually inspect files, run diagnostics, or add network tools, execute a shell session:

```bash
docker exec -it cups /bin/sh
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
    docker pull ghcr.io/jelliuk/docker-cups:latest
    ```

### ⚙️ Technical Specifications & Networking

*   **Base Image:** Debian Trixie Slim (Optimized for stability and reduced size).
*   **Networking Ports Exposed:**
    *   `631/tcp`: Standard IPP port for printer sharing.
    *   `5353/udp`: Mandatory Multicast DNS (mDNS) / Avahi port, enabling Bonjour discovery on the local network.
*   **Dependencies:** The container includes core packages such as `cups`, `avahi-daemon`, `ghostscript`, and specialized drivers (`printer-driver-foo2zjs`, `printer-driver-splix`).
*   **Development Status:** This image is maintained for personal use only. While usage is welcomed, dedicated user support cannot be provided due to time constraints.

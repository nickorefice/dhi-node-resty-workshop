# Docker Hardened Images (DHI) Workshop

A hands-on workshop demonstrating migration from Docker Official Images (DOI) to Docker Hardened Images (DHI), featuring a TypeScript Node.js API with OpenResty reverse proxy and Full ICU internationalization support.

## Overview

This workshop guides you through:

- **Exploring** DHI catalog and comparing with DOI
- **Customizing** DHI images (Full ICU for Node.js)
- **Building** and running applications with DHI
- **Scanning** images for vulnerabilities with Trivy
- **Debugging** production containers with docker debug

## Architecture

```
┌─────────────┐
│   Browser   │
│  localhost  │
│   :8080     │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐
│  OpenResty  │────▶│   Node.js    │
│   (DHI)     │     │   (DHI+ICU)  │
│   Port 80   │     │   Port 3000  │
└─────────────┘     └──────────────┘
```

### Components

- **Node.js API** (TypeScript): REST endpoints with ICU internationalization
- **OpenResty**: Reverse proxy (NGINX + LuaJIT) with security headers and gzip
- **Full ICU**: Complete locale/timezone/currency support for global apps

## Quick Start

### Prerequisites

```bash
# Required
docker --version                  # Docker Desktop or Docker Engine
docker compose version            # Compose V2
docker login                      # Authenticate with Docker Hub (required for DHI images)

# Optional (for scanning)
trivy --version                   # Trivy security scanner
```

**Note:** Docker Hardened Images (DHI) require a Docker subscription (Pro, Team, or Business). If you don't have access, you can still follow along using the DOI examples, or use `demonstrationorg` which may be available for workshop purposes.

### 1. Start with DOI (Before DHI)

```bash
# Run application with Docker Official Images
docker compose -f compose.doi.yaml up --build

# Open browser (visit http://localhost:8080 in your browser)
# macOS: open http://localhost:8080
# Linux: xdg-open http://localhost:8080 (or manually open browser)
# Windows: start http://localhost:8080

# Test API
curl http://localhost:8080/api/health
curl "http://localhost:8080/api/time?locale=en-US&tz=America/New_York"

# Stop
docker compose -f compose.doi.yaml down
```

### 2. Migrate to DHI (After)

```bash
# IMPORTANT: First update organization name in Dockerfiles
#
# The Dockerfiles currently use 'demonstrationorg' which may be available for workshops.
# If you have your own DHI subscription, replace 'demonstrationorg' with your organization name in:
# - docker/node/Dockerfile.dhi.dev (line 22)
# - docker/node/Dockerfile.dhi.prod (lines 31 and 61)
# - docker/openresty/Dockerfile.dhi (line 38)
#
# To find your organization name:
# 1. Log in to Docker Hub
# 2. Navigate to your organization's DHI images
# 3. Use the organization name from the image path (e.g., 'yourorg/dhi-node')
#
# If using demonstrationorg for this workshop, no changes are needed.

# Run application with Docker Hardened Images + Full ICU
docker compose -f compose.dhi.yaml up --build

# Open browser (visit http://localhost:8080 in your browser)
# macOS: open http://localhost:8080
# Linux: xdg-open http://localhost:8080 (or manually open browser)
# Windows: start http://localhost:8080

# Test Full ICU with various locales
curl "http://localhost:8080/api/time?locale=ja-JP&tz=Asia/Tokyo"
curl "http://localhost:8080/api/time?locale=fr-FR&tz=Europe/Paris"
curl "http://localhost:8080/api/time?locale=ar-SA&tz=Asia/Riyadh"
curl "http://localhost:8080/api/time?locale=hi-IN&tz=Asia/Kolkata"

# Stop
docker compose -f compose.dhi.yaml down
```

## Scanning Images for Security Comparison

A key benefit of DHI is **dramatically reduced CVE counts**. This section walks through scanning images BEFORE and AFTER migrating to DHI to demonstrate the security improvement.

### Install Trivy Scanner

```bash
# macOS
brew install aquasecurity/trivy/trivy

# Linux - see Trivy installation docs for your distro:
# https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Or use Docker (works on all platforms)
alias trivy='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy'
```

### Step 1: Scan BEFORE Migration (DOI Baseline)

**Scan the Docker Official Images you're currently using:**

```bash
# Scan Node.js DOI (terminal output)
./scripts/scan-image.sh node:20-bookworm

# Scan OpenResty DOI (terminal output)
./scripts/scan-image.sh openresty/openresty:1.27.1.2-0-bookworm-fat

# OR save to file for later comparison (JSON format)
./scripts/scan-image.sh node:20-bookworm trivy-doi-node.json
./scripts/scan-image.sh openresty/openresty:1.27.1.2-0-bookworm-fat trivy-doi-openresty.json

# OR manually save detailed results
trivy image --severity HIGH,CRITICAL --format table -o trivy-doi-node.txt node:20-bookworm
trivy image --severity HIGH,CRITICAL --format json -o trivy-doi-node.json node:20-bookworm
```

**Record the baseline metrics:**
- Critical CVEs: ___
- High CVEs: ___
- Medium CVEs: ___
- Image size: ___
- Total packages: ___

**Tip:** Save scan results to files to easily compare before/after metrics and include in documentation.

### Step 2: Migrate to DHI

Follow the migration steps above (`docker compose -f compose.dhi.yaml up --build`)

### Step 3: Scan AFTER Migration (DHI Comparison)

**Scan the Docker Hardened Images you migrated to:**

**Note:** Replace `demonstrationorg` with your organization name in all commands below if you're using your own DHI subscription.

```bash
# Scan Node.js DHI (development variant)
./scripts/scan-image.sh demonstrationorg/dhi-node:22-alpine3.22-dev

# Scan OpenResty DHI
./scripts/scan-image.sh demonstrationorg/dhi-openresty:1.27.1-debian13

# Scan Node.js DHI (production variant - even more secure)
./scripts/scan-image.sh demonstrationorg/dhi-node:22-alpine3.22

# OR save all results to files for comparison
./scripts/scan-image.sh demonstrationorg/dhi-node:22-alpine3.22-dev trivy-dhi-node-dev.json
./scripts/scan-image.sh demonstrationorg/dhi-node:22-alpine3.22 trivy-dhi-node-prod.json
./scripts/scan-image.sh demonstrationorg/dhi-openresty:1.27.1-debian13 trivy-dhi-openresty.json

# Manually save with custom formats
trivy image --severity HIGH,CRITICAL --format table -o trivy-dhi-node.txt demonstrationorg/dhi-node:22-alpine3.22
trivy image --severity HIGH,CRITICAL --format json -o trivy-dhi-node.json demonstrationorg/dhi-node:22-alpine3.22
```

**Compare saved results:**

```bash
# View JSON files for detailed analysis
cat trivy-doi-node.json | jq '.Results[].Vulnerabilities | length'  # Count DOI vulnerabilities
cat trivy-dhi-node-prod.json | jq '.Results[].Vulnerabilities | length'  # Count DHI vulnerabilities

# Or simply diff the text outputs
diff trivy-doi-node.txt trivy-dhi-node.txt
```

### Step 4: Compare Results

**Create a comparison table:**

| Metric | DOI Node | DHI Node (-dev) | DHI Node (prod) | Improvement |
|--------|----------|-----------------|-----------------|-------------|
| Critical CVEs | ___ | ___ | ___ | __% reduction |
| High CVEs | ___ | ___ | ___ | __% reduction |
| Medium CVEs | ___ | ___ | ___ | __% reduction |
| Image Size | ___ MB | ___ MB | ___ MB | __% smaller |
| Packages | ___ | ___ | ___ | __% fewer |

**Expected DHI Benefits:**
- ✅ Significant reduction in HIGH/CRITICAL CVEs
- ✅ 50-80% smaller image size (especially production variants)
- ✅ 60-90% fewer packages (reduced attack surface)
- ✅ Supply chain attestations (SBOM, provenance, VEX)
- ✅ Faster security patch delivery
- ✅ Compliance-ready hardened base

**Note:** Production variants (`22-alpine3.22`) will show even better numbers than `-dev` variants because they have no shell, no package manager, and minimal tools.

### Optional: Advanced Comparison with Docker Scout

Docker Scout provides a more comprehensive comparison between images, including policy evaluation, supply chain insights, and detailed vulnerability analysis.

**Prerequisites:**
- Docker Desktop installed (includes Docker Scout)
- Or Docker CLI with Scout plugin
- Docker Hub account (free tier sufficient)

**Enable Docker Scout:**

```bash
# Login to Docker Hub (required for Scout)
docker login

# Verify Scout is available
docker scout version
```

**Compare DOI vs DHI Images:**

**Note:** Replace `demonstrationorg` with your organization name in all commands below if you're using your own DHI subscription.

```bash
# Compare Node.js: DOI baseline vs DHI development
docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22-dev

# Compare Node.js: DOI vs DHI production 
docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22

# Compare OpenResty: DOI vs DHI
docker scout compare --to openresty/openresty:1.27.1.2-0-bookworm-fat demonstrationorg/dhi-openresty:1.27.1-debian13
```

**Save Scout results to files** (recommended to avoid terminal truncation):

```bash
# Save as Markdown for documentation
docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22-dev \
  --format markdown > scout-node-comparison.md

docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22-dev

docker scout compare --to node:20-bookworm demonstrationorg/dhi-node:22-alpine3.22

docker scout compare --to openresty/openresty:1.27.1.2-0-bookworm-fat demonstrationorg/dhi-openresty:1.27.1-debian13 

```

**Understanding Scout Output:**

Docker Scout shows:
- **Vulnerability comparison**: CVEs added/removed/unchanged
- **Severity breakdown**: Critical, High, Medium, Low counts
- **Package changes**: Packages added/removed
- **Policy violations**: Security policy compliance (if configured)
- **Recommendations**: Suggested actions for improvement

**Example Output (Real Comparison):**

```
## Overview

                    │            Analyzed Image                │      Comparison Image
────────────────────┼──────────────────────────────────────────┼─────────────────────────────
  Target            │  demonstrationorg/dhi-node:22-alpine3.22-dev  │  node:20-bookworm
    vulnerabilities │    0C     0H     1M     2L               │    0C     2H     3M   153L
                    │           -2     -2   -151               │
    size            │ 70 MB (-368 MB)                          │ 438 MB
    packages        │ 232 (-510)                               │ 742
```

**What This Means:**
- ✅ **100% reduction in HIGH vulnerabilities** (2 → 0)
- ✅ **84% smaller image size** (438MB → 70MB)
- ✅ **69% fewer packages** (742 → 232)
- ✅ **96% reduction in total CVEs** (158 → 3)

This demonstrates DHI's dramatic security and efficiency improvements!

**Scout vs Trivy:**

| Feature | Trivy | Docker Scout |
|---------|-------|--------------|
| Vulnerability scanning | ✅ Comprehensive | ✅ Comprehensive |
| Comparison mode | ❌ Manual | ✅ Built-in compare |
| Policy evaluation | ❌ No | ✅ Yes |
| Supply chain insights | Limited | ✅ Detailed |
| SBOM analysis | ✅ Yes | ✅ Yes + Attestations |
| Docker Hub integration | ❌ No | ✅ Yes |
| Free tier | ✅ Yes | ✅ Yes (limited) |

**Recommended Workflow:**

1. **Trivy for quick scans**: Fast, offline-capable, scriptable
2. **Docker Scout for detailed comparison**: Policy evaluation, supply chain analysis, visual reporting
3. **Both together**: Trivy for baseline scanning, Scout for stakeholder reports

**Docker Desktop GUI:**

If using Docker Desktop:
1. Open Docker Desktop
2. Navigate to **Images** tab
3. Select an image
4. Click **"Scout"** button
5. Click **"Compare"** to select comparison target
6. View side-by-side vulnerability analysis

**Scripting and Automation:**

Docker Scout can be used in scripts and automation:

```bash
# Save comparison results for reporting
docker scout compare \
  --to node:20-bookworm \
  --format sarif \
  --output scout-results.sarif \
  demonstrationorg/dhi-node:22-alpine3.22
```

**Additional Scout Features:**

```bash
# View CVEs specific to your image (not from base)
docker scout cves --only-cve-id demonstrationorg/dhi-node:22-alpine3.22-dev

# Check policy compliance
docker scout policy demonstrationorg/dhi-node:22-alpine3.22-dev

# View recommendations for remediation
docker scout recommendations demonstrationorg/dhi-node:22-alpine3.22-dev

# Compare against latest tag
docker scout compare --to demonstrationorg/dhi-node:latest demonstrationorg/dhi-node:22-alpine3.22
```

**Learn More:**
- [Docker Scout Documentation](https://docs.docker.com/scout/)
- [Docker Scout CLI Reference](https://docs.docker.com/reference/cli/docker/scout/)
- [Docker Scout in Docker Desktop](https://docs.docker.com/desktop/use-desktop/image-explorer/)

## Debugging DHI Production Containers

DHI production images (`22-alpine3.22`, `1.28.0-alpine3.21`) intentionally have **no shell** for security. This prevents traditional debugging with `docker exec -it <container> sh`.

Docker provides `docker debug` to access these containers without compromising security.

### The Problem: No Shell Access

```bash
# Traditional approach FAILS with production DHI
docker exec -it <container> sh

# Error: "exec: 'sh': executable file not found in $PATH"
```

### The Solution: docker debug

`docker debug` attaches an ephemeral debug container with a full shell to inspect your running container.

**Prerequisites:**
- Docker Desktop (includes docker debug plugin)

**Test with production DHI container:**

```bash
# Start a production DHI container (no shell)
# Note: No backslash needed - keep command on one line or ensure no trailing spaces after \
docker run -d --name dhi-test demonstrationorg/dhi-node:22-alpine3.22 node -e "setInterval(() => console.log('Running...'), 5000)"

# Verify container is running
docker ps --filter name=dhi-test

# Try traditional exec (will fail)
docker exec dhi-test sh
# Error: "exec: 'sh': executable file not found in $PATH"

# Use docker debug instead (works!)
# Run a single command
docker debug --command 'ps aux' dhi-test

# Or start an interactive shell
docker debug dhi-test
```

**Common debugging tasks:**

```bash
# Explore container filesystem
docker debug --command 'ls -la /' <container>

# Check running processes
docker debug --command 'ps aux' <container>

# View container OS and environment
docker debug --command 'cat /etc/os-release' <container>

# Check what tools are available in the debug shell
docker debug --command 'which ps cat ls curl vim' <container>

# Check process command line
docker debug --command 'cat /proc/1/cmdline' <container>

# Confirm container entry point and CMD
docker debug --command 'entrypoint' <container>

# Interactive shell for complex debugging
docker debug <container>
# Opens bash/zsh/fish with access to container filesystem and processes
```

**What docker debug provides:**
- ✅ Full shell (zsh, bash, fish) even when target has no shell
- ✅ Access to target container's filesystem and process namespace
- ✅ Common debugging tools pre-installed (vim, nano, htop, curl, etc.)
- ✅ **Builtin `install` command** - add any tool from [nixos.org/packages](https://search.nixos.org/packages)
- ✅ **Zero image modification** - tools added only to your isolated toolbox (never to the image/container)
- ✅ **Persistent toolbox** - installed tools remain available across debug sessions
- ✅ **Entry point confirmation** - `entrypoint` builtin shows ENTRYPOINT/CMD interactions
- ✅ **Remote debugging** - debug containers on remote Docker hosts with `--host`
- ✅ **Custom toolbox support** - create your own debugger image with pre-installed tools
- ✅ Ephemeral - debug container removed when you exit

**Use Cases:**
- Inspect production DHI containers locally
- Debug "no shell" errors during development
- Troubleshoot application behavior without modifying images
- Verify file permissions and ownership
- Check environment variables and configuration

### Advanced: Custom Toolbox and Remote Debugging

**Quick Example: Installing netstat**

```bash
# This fails - netstat not in default toolbox
docker debug --command 'netstat -tulpn' <container>
# Error: command not found: netstat

# Solution 1: Use the builtin install command
docker debug <container>
$ install nettools
$ netstat -tulpn
# Works! And persists for all future debug sessions

# Solution 2: One-liner (non-interactive)
docker debug --command 'install nettools && netstat -tulpn' <container>
```

**Understanding the Toolbox:**

Docker Debug uses an isolated **Nix-based toolbox** that overlays your container without modifying the actual image. The toolbox lives in `/nix` (invisible to your container) and provides a persistent environment for debugging tools.

**Key Insight:** Tools you install are added **only to your toolbox**, never to the image or container. Search for packages at [search.nixos.org/packages](https://search.nixos.org/packages).

**Installing Tools with the `install` Builtin:**

The `install` command adds packages from [nixos.org/packages](https://search.nixos.org/packages):

```bash
# Start interactive debug session
docker debug <container>

# Use the builtin install command
$ install nmap netcat strace tcpdump

# Tools are now available
$ nmap --version
$ netstat -tulpn

# Check what's installed
$ builtins
Available commands:
  install     - Install Nix packages from nixos.org/packages
  uninstall   - Remove installed packages
  entrypoint  - Show/lint/execute container entry point
  builtins    - Display this help

# Uninstall tools you no longer need
$ uninstall nmap
```

**Tool Persistence:**

Once installed, tools remain in your toolbox across all future debug sessions—even with different images! You only install once.

**Confirming Entry Points:**

The `entrypoint` builtin helps understand how containers start:

```bash
# Show effective entry point and CMD
docker debug --command 'entrypoint' <container>

# Example output:
# ENTRYPOINT: ["node"]
# CMD: ["index.js"]
# Effective command: node index.js

# Interactive mode
docker debug <container>
$ entrypoint
$ entrypoint --lint    # Validate syntax
$ entrypoint --exec    # Execute the entry point
```

This is invaluable for debugging startup issues in production DHI containers where you can't easily inspect the Dockerfile.

**Remote Container Debugging:**

Debug containers running on remote Docker hosts using the `--host` flag:

```bash
# Debug container on remote host via SSH
docker debug --host ssh://root@production-server.com <container>

# Debug via Unix socket
docker debug --host unix:///path/to/docker.sock <container>

# Also works with DOCKER_HOST environment variable
export DOCKER_HOST=ssh://user@remote-host
docker debug <container>

# Or with Docker contexts
docker context use production
docker debug <container>
```

This means you can bring your **entire customized toolbox** to containers running anywhere—local, staging, or production—without SSH'ing into the host first.

**Example Workflow: Network Debugging**

```bash
# Install network debugging tools once
docker debug <container>
$ install nmap tcpdump wireshark-cli netcat

# Use them immediately
$ nmap -sn 172.17.0.0/16     # Scan Docker network
$ tcpdump -i any port 3000   # Capture traffic
$ nc -zv app-server 8080     # Test connectivity

# Tools persist - available in all future debug sessions
$ exit

# Days later, debug a different container - tools already available!
docker debug <another-container>
$ nmap --version  # Still there!
```


**Why Docker Debug > Traditional Approaches:**

| Capability | docker exec | docker debug |
|-----------|-------------|--------------|
| Works on slim/distroless images | ❌ No | ✅ Yes |
| Zero image modification | ❌ No | ✅ Yes |
| Persistent tools across sessions | ❌ No | ✅ Yes |
| Remote debugging | ⚠️ Requires SSH | ✅ Built-in --host |
| Entry point inspection | ❌ No | ✅ entrypoint builtin |
| Isolated toolbox | ❌ No | ✅ /nix overlay |
| 60,000+ packages available | ❌ No | ✅ nixos.org |
| Custom toolbox images | ❌ No | ✅ --image flag |

**Requirements:**

- **Docker Desktop 4.49+** (includes `docker debug` by default)
- Earlier versions (4.48.0 and prior) require Pro, Team, or Business subscriptions
- For Docker Engine without Desktop, install the [docker/debug-cli-plugin](https://github.com/docker/debug-cli-plugin)

**Cleanup:**

```bash
# Exit debug shell (Ctrl+D or exit)
# Debug container is automatically removed

# Stop and remove test container
docker stop dhi-test && docker rm dhi-test
```


**Learn More:**
- [Docker Debug CLI Reference](https://docs.docker.com/reference/cli/docker/debug/)
- [Debugging Containers without Shell](https://www.docker.com/blog/docker-debug-ga/)
- [NixOS Package Search](https://search.nixos.org/packages)
- For Kubernetes: [`kubectl debug`](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container)

---

## Alternative: Multi-Stage Builds for Development vs Production

While `docker debug` is excellent for inspecting production containers, you can also use **multi-stage builds** to create separate development and production images from the same Dockerfile.

### Why Use Multi-Stage Builds?

- ✅ **Single Dockerfile** for both dev and prod environments
- ✅ **Smaller production images** using hardened base images
- ✅ **Full tooling in development** with shells and debugging tools
- ✅ **Consistent builds** across environments
- ✅ **No runtime overhead** in production

### Example: Node.js Application with DHI

**Dockerfile with Multi-Stage Builds:**

```dockerfile
# syntax=docker/dockerfile:1

# Build stage - uses regular node image for building
FROM node:22-alpine3.22 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .

# Production stage - minimal, hardened image (no shell)
FROM demonstrationorg/dhi-node:22-alpine3.22 AS production
WORKDIR /app
# Copy built app from builder stage
COPY --from=builder /app /app
CMD ["node", "index.js"]

# Debug stage - includes shell and debugging tools
FROM node:22-alpine3.22 AS debug
WORKDIR /app
COPY --from=builder /app /app
# Add debugging tools
RUN apk add --no-cache bash curl wget procps
CMD ["node", "index.js"]
```

**Build and test image sizes:**

```bash
# Build production image (hardened, no shell)
docker build -t myapp:production --target production .

# Build debug image (with shell and tools)
docker build -t myapp:debug --target debug .

# Test production image (no shell access)
docker run -d --name myapp-prod myapp:production
docker exec myapp-prod sh
# Error: exec: "sh": executable file not found in $PATH

# Test debug image (with shell access)
docker run -d --name myapp-dev myapp:debug
docker exec myapp-dev sh -c "echo 'Shell works!' && ps aux && curl --version"
# Success: Shows shell access and installed tools

# Compare image sizes
docker images | grep myapp
# myapp    debug        ...    172MB
# myapp    production   ...    128MB   # 44MB smaller!
```

**Use docker debug on production image (no shell):**

Even with the minimal production image, you can still use `docker debug` for troubleshooting:

```bash
# Debug the production container without modifying it
docker debug --command 'ps aux' myapp-prod
docker debug --command 'cat /etc/os-release' myapp-prod

# Or open an interactive debug shell
docker debug myapp-prod
```

### Key Insights

1. **DHI Images Cannot Run Shell Commands During Build**
   - DHI images have no shell, so `RUN` commands will fail
   - Solution: Use a regular image in the builder stage, then copy artifacts to DHI
   - ❌ `FROM dhi-node:22 ... RUN npm install` (fails)
   - ✅ `FROM node:22 AS builder ... RUN npm install` then `COPY --from=builder`

2. **When to Use Each Approach**
   - **Multi-stage builds**: Known dev/prod split, automated builds, consistent environments
   - **docker debug**: Ad-hoc debugging, production image troubleshooting, inspecting running containers

3. **Best of Both Worlds**
   - Use multi-stage builds for your development workflow
   - Use `docker debug` for production image troubleshooting
   - Keep production images minimal and hardened
   - Enable full debugging capabilities when needed

**Learn More:**
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Multi-Stage Builds for Different Environments](https://docs.docker.com/build/building/multi-stage/#use-multi-stage-builds)

---

## Repository Structure

```
.
├── app/                          # TypeScript Node.js application
│   ├── src/server.ts             # API server with ICU endpoints
│   ├── public/index.html         # Interactive ICU demo UI
│   ├── package.json              # Dependencies
│   └── tsconfig.json             # TypeScript config
│
├── docker/                       # Dockerfiles
│   ├── node/
│   │   ├── Dockerfile.doi.dev    # DOI Node.js development
│   │   ├── Dockerfile.doi.prod   # DOI Node.js production
│   │   ├── Dockerfile.dhi.dev    # DHI Node.js development + Full ICU
│   │   └── Dockerfile.dhi.prod   # DHI Node.js production + Full ICU
│   └── openresty/
│       ├── default.conf          # OpenResty configuration
│       ├── Dockerfile.doi        # DOI OpenResty
│       └── Dockerfile.dhi        # DHI OpenResty
│
├── compose.doi.yaml              # Docker Compose for DOI
├── compose.dhi.yaml              # Docker Compose for DHI
│
├── scripts/                      # Utility scripts
│   └── scan-image.sh             # Scan images with Trivy
│
├── customization/                # Customization guides
│   └── full-icu/README.md        # Full ICU documentation
│
├── README.md                     # This file
```

## API Endpoints

### Health Check
```bash
GET /api/health

Response:
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Time Formatting (ICU Demo)
```bash
GET /api/time?locale=<locale>&tz=<timezone>

Examples:
  /api/time?locale=ja-JP&tz=Asia/Tokyo
  /api/time?locale=fr-FR&tz=Europe/Paris
  /api/time?locale=ar-SA&tz=Asia/Riyadh

Response:
{
  "locale": "ja-JP",
  "tz": "Asia/Tokyo",
  "formatted": "2024年1月15日月曜日 19:30:00 日本標準時",
  "numberExample": "¥12,346",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "icuDataPath": "/usr/share/icu"
}
```

## Full ICU Customization

The DHI Node.js images include **Full ICU** support for comprehensive internationalization:

### What is Full ICU?

- **600+ locales**: Support for all languages and regions
- **Complete timezones**: All IANA timezone database
- **Currency formatting**: All world currencies with symbols
- **Date/time formatting**: Locale-specific formats
- **Number formatting**: Locale-aware display

### Implementation

```dockerfile
# In docker/node/Dockerfile.dhi.*
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    icu-data-full && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_ICU_DATA=/usr/share/icu
```

### Testing Full ICU

Open http://localhost:8080 and select different locales/timezones from the dropdowns.

See [customization/full-icu/README.md](customization/full-icu/README.md) for detailed documentation.

## Workshop Guide

For a complete workshop walkthrough, see [WORKSHOP.md](WORKSHOP.md).

The workshop covers:
1. Pre-requisites and setup
2. Exploring and selecting DHI images
3. Customizing images (Full ICU)
4. Scanning and local builds
5. Using dependent images (OpenResty)
6. Debugging production containers
7. Wrap-up and best practices

## Production Best Practices

### Image Pinning

**Workshop uses** `:latest` tags for simplicity.

**Production should use** digest pinning:

```dockerfile
# Instead of:
FROM demonstrationorg/dhi-node:latest

# Use:
FROM demonstrationorg/dhi-node@sha256:abc123def456...
```

Get digest:
```bash
docker pull demonstrationorg/dhi-node:latest
docker inspect demonstrationorg/dhi-node:latest --format='{{index .RepoDigests 0}}'
```

### Security Scanning

- **Scan regularly**: Schedule regular scans with Trivy or Docker Scout
- **Monitor updates**: Subscribe to DHI security notifications
- **Update promptly**: Apply DHI updates when available
- **Baseline tracking**: Document and track CVE counts over time

### Customization Guidelines

- **Minimize additions**: Only add what's truly needed
- **Document why**: Explain business requirement
- **Security review**: Evaluate each package added
- **Keep updated**: Monitor for security patches

## Troubleshooting

### Port Already in Use

```bash
# Find and stop conflicting services
lsof -ti:8080 | xargs kill -9

# Or use different port in compose.yaml
ports:
  - "8081:80"  # Change 8080 to 8081
```

### Trivy Not Found

```bash
# macOS
brew install aquasecurity/trivy/trivy

# Linux - see Trivy installation docs for your distro:
# https://aquasecurity.github.io/trivy/latest/getting-started/installation/

# Or use Docker (works on all platforms)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <image-name>
```

### Full ICU Not Working

```bash
# Verify ICU data path
docker compose -f compose.dhi.yaml exec app printenv NODE_ICU_DATA
# Should output: /usr/share/icu

# Check if package installed
docker compose -f compose.dhi.yaml exec app dpkg -l | grep icu-data
```

## Resources

- [Docker Hardened Images Documentation](https://docs.docker.com/hardened-images/)
- [Node.js Internationalization](https://nodejs.org/api/intl.html)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Scout Documentation](https://docs.docker.com/scout/)
- [Docker Debug Documentation](https://docs.docker.com/reference/cli/docker/debug/)

## Support

For questions or issues:

1. Review [customization/full-icu/README.md](customization/full-icu/README.md) for ICU details
2. Consult Docker Hardened Images documentation
3. Contact your Docker sales representative

## License

This workshop material is provided for educational purposes.

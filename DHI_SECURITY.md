# DHI Security Model - Critical Concepts

## Overview

Docker Hardened Images (DHI) implement an aggressive security-first design that **fundamentally changes** how you work with container images. Understanding these constraints is essential for successful adoption.

## The Core Security Feature: No Shell in Production

### Production DHI Images

**Production DHI images intentionally remove:**
- ❌ `/bin/sh` and all shells
- ❌ Package managers (`apk`, `apt`, `yum`)
- ❌ Root user access
- ❌ Build tools and compilers
- ❌ Debugging utilities

**Why?** Each of these is a potential attack vector. By removing them, DHI creates the minimal possible attack surface.

### Development DHI Images (`-dev` suffix)

**Development DHI images (`-dev`) include:**
- ✅ Shell (`/bin/sh`)
- ✅ Package manager (`apk` for Alpine)
- ✅ Build tools
- ✅ Debugging utilities

**Purpose:** Enable customization and building during development/CI

## The Multi-Stage Build Pattern

This is the **recommended** pattern for DHI customization:

```dockerfile
# ============================================================
# BUILD STAGE: Use -dev variant (has shell, apk, tools)
# ============================================================
FROM demonstrationorg/dhi-node:22-alpine3.22-dev AS builder

# ✅ Can use RUN commands (shell exists)
RUN apk add --no-cache icu-data-full

# ✅ Can install dependencies
RUN npm ci

# ✅ Can build application
RUN npm run build

# ============================================================
# RUNTIME STAGE: Use production variant (NO shell, NO apk)
# ============================================================
FROM demonstrationorg/dhi-node:22-alpine3.22

# ❌ CANNOT use RUN commands (no shell!)
# RUN apk add something  # This will FAIL!

# ✅ CAN copy from builder
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/share/icu /usr/share/icu

# ✅ CAN use ENV, EXPOSE, CMD (Dockerfile instructions)
ENV NODE_ICU_DATA=/usr/share/icu
EXPOSE 3000

# ⚠️  Must use exec form (array) for CMD - no shell to interpret
CMD ["node", "dist/server.js"]
```

## What Works and What Doesn't

### ✅ WORKS in Production DHI

| Dockerfile Instruction | Works? | Notes |
|------------------------|--------|-------|
| `FROM` | ✅ Yes | Start runtime stage with production DHI |
| `COPY` | ✅ Yes | Copy files from builder or context |
| `COPY --from=builder` | ✅ Yes | Copy artifacts from build stage |
| `ENV` | ✅ Yes | Set environment variables |
| `EXPOSE` | ✅ Yes | Document exposed ports |
| `WORKDIR` | ✅ Yes | Set working directory |
| `USER` | ✅ Yes | Switch user (already non-root) |
| `CMD ["exec", "form"]` | ✅ Yes | Use array form (no shell) |
| `ENTRYPOINT ["exec"]` | ✅ Yes | Use array form (no shell) |

### ❌ FAILS in Production DHI

| Dockerfile Instruction | Works? | Error |
|------------------------|--------|-------|
| `RUN apk add ...` | ❌ No | `stat /bin/sh: no such file or directory` |
| `RUN apt-get ...` | ❌ No | No shell exists |
| `RUN npm install` | ❌ No | No shell to execute |
| `RUN adduser ...` | ❌ No | No shell, no useradd |
| `CMD command string` | ❌ No | No shell to interpret |
| `HEALTHCHECK CMD curl` | ❌ No | No shell for curl |

## Development vs Production Strategy

### Development (compose.dhi.yaml)

Use `-dev` variants for convenience:

```yaml
services:
  app:
    build:
      dockerfile: docker/node/Dockerfile.dhi.dev
    # Built from: demonstrationorg/dhi-node:22-alpine3.22-dev
```

**Benefits:**
- Has shell for debugging (`docker exec -it app sh`)
- Can install packages on the fly
- Easier troubleshooting
- Hot reload works normally

**Trade-offs:**
- Larger image size
- More attack surface
- Not production-representative

### Production (Dockerfile.dhi.prod)

Use multi-stage with production variant:

```yaml
# Build stage: -dev (has tools)
FROM demonstrationorg/dhi-node:22-alpine3.22-dev AS builder
RUN apk add --no-cache icu-data-full
RUN npm ci && npm run build

# Runtime stage: production (no tools)
FROM demonstrationorg/dhi-node:22-alpine3.22
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/share/icu /usr/share/icu
CMD ["node", "dist/server.js"]
```

**Benefits:**
- Minimal attack surface (no shell/apk)
- Smallest possible image
- Cannot be compromised via shell access
- Production-hardened

**Trade-offs:**
- Cannot debug with `docker exec sh`
- Must rebuild to add packages
- Requires multi-stage builds

## Common Errors and Solutions

### Error: `stat /bin/sh: no such file or directory`

**Cause:** Trying to use `RUN` command in production DHI

**Solution:** Move all `RUN` commands to `-dev` build stage

```dockerfile
# ❌ WRONG
FROM demonstrationorg/dhi-node:22-alpine3.22
RUN apk add something  # FAILS!

# ✅ CORRECT
FROM demonstrationorg/dhi-node:22-alpine3.22-dev AS builder
RUN apk add something  # Works!

FROM demonstrationorg/dhi-node:22-alpine3.22
COPY --from=builder /installed/files ./
```

### Error: Cannot exec into running container

**Cause:** Production DHI has no shell

**Solution:** Use `-dev` variant for development, or use:

```bash
# For debugging production images, use an ephemeral debug container
kubectl debug pod/my-pod -it --image=busybox --target=my-container

# Or add debug sidecar in k8s
```

### Error: npm/yarn commands fail in production

**Cause:** No shell to execute package manager

**Solution:** Install dependencies in `-dev` build stage, copy to production

```dockerfile
FROM demonstrationorg/dhi-node:22-alpine3.22-dev AS builder
RUN npm ci  # Works here

FROM demonstrationorg/dhi-node:22-alpine3.22
COPY --from=builder /usr/src/app/node_modules ./node_modules  # Copy results
```

## Customization Strategies

### 1. Multi-Stage Build (Recommended)

Install in `-dev`, copy to production:

```dockerfile
FROM demonstrationorg/dhi-node:22-alpine3.22-dev AS builder
RUN apk add --no-cache icu-data-full ca-certificates
COPY app/ /app
RUN cd /app && npm ci && npm run build

FROM demonstrationorg/dhi-node:22-alpine3.22
COPY --from=builder /usr/share/icu /usr/share/icu
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /app/dist /app/dist
CMD ["node", "/app/dist/server.js"]
```

### 2. Custom DHI Mirror (For Persistent Changes)

Use Docker Hub to create a custom mirror with pre-installed packages:

1. Navigate to Docker Hub
2. Select "Create Repository" → "Mirror DHI"
3. Choose base DHI image
4. Add packages via customizations (icu-data-full, ca-certificates, etc.)
5. Docker builds and maintains your custom DHI

**Benefits:**
- No multi-stage complexity
- Packages maintained by Docker
- Automatic security updates


## Security Benefits

### Attack Surface Reduction

**Traditional container:**
```
Image Size: 950MB
Packages: 500+
Shell: bash, sh
Package Manager: apt, dpkg
Root Access: Yes
Common CVEs: 50+ HIGH/CRITICAL
```

**DHI Production:**
```
Image Size: 40MB
Packages: 20-30 (minimal)
Shell: NONE
Package Manager: NONE
Root Access: NO
Common CVEs: 0 HIGH/CRITICAL fixable CVEs
```

### Real-World Impact

| Attack Vector | Traditional | DHI Production |
|---------------|-------------|----------------|
| Shell exploitation | ✅ Possible | ❌ No shell exists |
| Package manager exploit | ✅ Possible | ❌ Not installed |
| Privilege escalation | ✅ Possible | ❌ No root access |
| Lateral movement | ✅ Easy (shell tools) | ❌ Minimal tools |
| Persistence mechanisms | ✅ Many options | ❌ Very limited |

## Best Practices

### DO:
- ✅ Use `-dev` variants for build/dev stages only
- ✅ Use production variants for final runtime images
- ✅ Copy artifacts from builder to production stage
- ✅ Use exec form for CMD/ENTRYPOINT (`["node", "app.js"]`)
- ✅ Test production images in staging before deploying
- ✅ Use external health checks (k8s probes, not Docker HEALTHCHECK)
- ✅ Pin images by digest for production (`@sha256:abc123...`)

### DON'T:
- ❌ Use `-dev` variants in production
- ❌ Try to install packages in production stage
- ❌ Expect shell commands to work in production
- ❌ Use shell form for CMD (`CMD node app.js`)
- ❌ Rely on debugging tools in production images
- ❌ Use `:latest` or `:stable` tags (don't exist in DHI)

## Transition Strategy

### Phase 1: Development (Week 1)
- Use `-dev` variants everywhere
- Test application functionality
- Identify customization needs

### Phase 2: Production Build (Week 2-3)
- Create multi-stage Dockerfile or customize production image
- Move customizations to build stage
- Test production image locally

### Phase 3: Staging (Week 4)
- Deploy production image to staging
- Verify monitoring/logging works without shell
- Update runbooks for no-shell debugging

### Phase 4: Production (Week 5+)
- Gradual rollout
- Monitor security posture improvement
- Document any operational changes

## Monitoring and Debugging

### Without Shell Access

**Traditional approach:**
```bash
docker exec -it container sh  # Won't work!
```

**DHI approaches:**

1. **Docker Debug** (Recommended for Local/Development):
   ```bash
   # Access running production DHI container with no shell
   docker debug <container-id>

   # Run specific commands
   docker debug <container> --command "ps aux"
   docker debug <container> --command "ls -la /usr/src/app"
   ```
   - ✅ Works with Docker Desktop or docker debug plugin
   - ✅ Ephemeral debug container with full shell
   - ✅ Access to target's filesystem and processes
   - ✅ No modification to production container
   - ✅ See README.md "Debugging DHI Production Containers" section

2. **Kubernetes Debug** (For K8s Environments):
   ```bash
   # Ephemeral debug container in Kubernetes
   kubectl debug pod/my-pod -it --image=busybox --target=my-container
   ```

3. **Application Logging**: Comprehensive logging to stdout/stderr

4. **APM Tools**: DataDog, New Relic, AppDynamics

5. **Distributed Tracing**: OpenTelemetry, Jaeger

6. **External Health**: Kubernetes liveness/readiness probes

### Health Checks

**Traditional (won't work):**
```dockerfile
HEALTHCHECK CMD curl http://localhost:3000/health
```

**DHI approach:**
```yaml
# kubernetes liveness probe
livenessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 30
```

## Summary

DHI's "no shell" design is not a limitation—it's a **security feature**. By forcing multi-stage builds and removing runtime tools, DHI achieves:

- 90%+ reduction in CVE count
- Elimination of common attack vectors
- Compliance-ready minimal attack surface
- Faster security patch delivery

The trade-off is operational: debugging requires different techniques, and customization requires multi-stage builds. For security-conscious organizations, this is an excellent trade-off.

## Additional Resources

- [Official DHI Documentation](https://docs.docker.com/dhi/)
- [DHI Customization Guide](https://docs.docker.com/dhi/how-to/customize/)
- [DHI Migration Guide](https://docs.docker.com/dhi/how-to/migrate/)
- [Docker Scout for DHI](https://docs.docker.com/scout/)

---

**Remember:** If you need shell access, you're using the wrong image variant. Use `-dev` for development, production for runtime.

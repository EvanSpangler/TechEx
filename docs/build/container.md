# Container Build

Complete documentation for building the Tasky application container image.

## Dockerfile Overview

The application uses a **multi-stage Docker build** for security and efficiency.

```dockerfile
# Build stage - compiles Go binary
FROM golang:1.19 AS build

# Release stage - minimal runtime image
FROM alpine:3.17.0 AS release
```

### Why Multi-Stage?

| Benefit | Description |
|---------|-------------|
| Smaller image | Final image ~15MB vs ~1GB with Go toolchain |
| Security | No build tools in production image |
| Reproducibility | Consistent builds across environments |
| Layer caching | Faster rebuilds when only code changes |

## Dockerfile Breakdown

### Stage 1: Build

```dockerfile
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky
```

| Line | Purpose |
|------|---------|
| `golang:1.19` | Official Go image with compiler |
| `WORKDIR /go/src/tasky` | Set working directory |
| `COPY . .` | Copy all source files |
| `go mod download` | Download dependencies (cached layer) |
| `CGO_ENABLED=0` | Static binary, no C dependencies |
| `GOOS=linux GOARCH=amd64` | Cross-compile for Linux x86_64 |

### Stage 2: Release

```dockerfile
FROM alpine:3.17.0 AS release

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy binary and assets
COPY --from=build /go/src/tasky/tasky .
COPY --from=build /go/src/tasky/assets ./assets

# Create wizexercise.txt as required by the exercise
RUN echo "Evan Spangler - Wiz Technical Exercise 2024" > /app/wizexercise.txt

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

ENTRYPOINT ["/app/tasky"]
```

## Security Features

### Non-Root User

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

- Creates system user/group (`-S` flag)
- Application runs as `appuser`, not `root`
- Limits impact of container escape vulnerabilities

### Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--interval` | 30s | Check every 30 seconds |
| `--timeout` | 3s | Fail if check takes >3s |
| `--start-period` | 5s | Grace period for startup |
| `--retries` | 3 | Mark unhealthy after 3 failures |

### Minimal Base Image

- **Alpine 3.17.0**: ~5MB base image
- No shell needed for production (but included for health check)
- Minimal attack surface

## Building Locally

### Basic Build

```bash
cd app
docker build -t tasky .
```

### Build with Tag

```bash
docker build -t tasky:$(git rev-parse --short HEAD) app/
```

### Build with Build Args

```bash
docker build \
  --build-arg VERSION=$(git describe --tags) \
  -t tasky:latest \
  app/
```

## Running Locally

### Basic Run

```bash
docker run -p 8080:8080 tasky
```

### With Environment Variables

```bash
docker run -p 8080:8080 \
  -e MONGODB_URI="mongodb://user:pass@localhost:27017/tasky" \
  -e JWT_SECRET="your-secret" \
  tasky
```

### Development Mode (with volume mount)

```bash
docker run -p 8080:8080 \
  -v $(pwd)/assets:/app/assets:ro \
  tasky
```

## Verifying the Build

### Check wizexercise.txt

```bash
docker run --rm tasky cat /app/wizexercise.txt
# Output: Evan Spangler - Wiz Technical Exercise 2024
```

### Verify Non-Root User

```bash
docker run --rm tasky whoami
# Output: appuser
```

### Test Health Check

```bash
docker run -d --name tasky-test -p 8080:8080 tasky
sleep 10
docker inspect --format='{{.State.Health.Status}}' tasky-test
# Output: healthy
docker rm -f tasky-test
```

## Image Scanning

### Trivy Scan

```bash
trivy image tasky:latest
```

### Grype Scan

```bash
grype tasky:latest
```

### CI/CD Scanning

The GitHub Actions workflow automatically scans images:

```yaml
- name: Trivy vulnerability scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

## Pushing to ECR

### Manual Push

```bash
# Authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# Tag
docker tag tasky:latest <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-tasky:latest

# Push
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-tasky:latest
```

### Via CI/CD

Pushing is handled automatically by the `build-deploy-app.yml` workflow on merges to `main`.

## Layer Optimization

### Current Layer Structure

```
Layer 1: Alpine base (~5MB)
Layer 2: User creation (~0.1MB)
Layer 3: Binary copy (~10MB)
Layer 4: Assets copy (~0.5MB)
Layer 5: wizexercise.txt (~0.1MB)
Layer 6: Ownership change (~0.1MB)
Total: ~15-16MB
```

### Caching Strategy

```dockerfile
# Dependencies cached separately from source
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build ...
```

This pattern ensures `go mod download` is cached unless dependencies change.

## Troubleshooting

### Build Fails: go mod download

```
Error: module lookup disabled by GOPROXY=off
```

**Solution**: Ensure network access or pre-download modules:

```bash
go mod vendor
docker build --build-arg GOFLAGS="-mod=vendor" -t tasky .
```

### Build Fails: Permission Denied

```
Error: permission denied while trying to connect to Docker daemon
```

**Solution**: Add user to docker group or use sudo:

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Container Won't Start

```bash
# Check logs
docker logs tasky

# Common issues:
# - Missing MONGODB_URI
# - Port already in use
# - Health check failing
```

### Health Check Failing

```bash
# Debug health check
docker exec tasky wget --spider http://localhost:8080/
```

## Related Documentation

- [Application Build](application.md) - Go compilation details
- [GitHub Actions](../reference/github-actions.md) - CI/CD pipeline
- [EKS Deployment](../infrastructure/eks.md) - Kubernetes deployment

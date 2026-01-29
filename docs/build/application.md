# Application Build

Documentation for building the Tasky Go application locally and understanding its structure.

## Application Overview

Tasky is a Go-based todo application with the following stack:

| Component | Technology |
|-----------|------------|
| Language | Go 1.19 |
| Web Framework | Gin |
| Database | MongoDB |
| Authentication | JWT |
| Templates | Go HTML templates |

## Source Structure

```
app/
├── main.go              # Application entry point
├── go.mod               # Go module definition
├── go.sum               # Dependency checksums
├── Dockerfile           # Container build
├── controllers/         # HTTP handlers
│   └── controllers.go
├── models/              # Data models
│   └── models.go
├── database/            # MongoDB connection
│   └── database.go
├── auth/                # JWT authentication
│   └── auth.go
└── assets/              # Static files & templates
    ├── css/
    ├── js/
    └── templates/
```

## Building Locally

### Prerequisites

```bash
# Check Go version (requires 1.19+)
go version

# Verify MongoDB is accessible (for testing)
mongosh --eval "db.version()"
```

### Download Dependencies

```bash
cd app
go mod download
```

### Build Binary

```bash
# Standard build
go build -o tasky

# Cross-compile for Linux (from macOS/Windows)
GOOS=linux GOARCH=amd64 go build -o tasky

# Static binary (no CGO)
CGO_ENABLED=0 go build -o tasky
```

### Build Flags

| Flag | Purpose |
|------|---------|
| `-o tasky` | Output binary name |
| `-ldflags="-s -w"` | Strip debug info (smaller binary) |
| `-race` | Enable race detector (development) |
| `-v` | Verbose output |

### Example: Production Build

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w" -o tasky
```

## Running Locally

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MONGODB_URI` | Yes | - | MongoDB connection string |
| `JWT_SECRET` | Yes | - | Secret for JWT signing |
| `PORT` | No | `8080` | HTTP listen port |

### With Local MongoDB

```bash
# Start MongoDB (if not running)
mongod --dbpath /data/db

# Set environment and run
export MONGODB_URI="mongodb://localhost:27017/tasky"
export JWT_SECRET="development-secret"
go run main.go
```

### With Docker MongoDB

```bash
# Start MongoDB container
docker run -d --name mongodb -p 27017:27017 mongo:4.4

# Run application
export MONGODB_URI="mongodb://localhost:27017/tasky"
export JWT_SECRET="development-secret"
go run main.go
```

## Go Modules

### go.mod

```go
module tasky

go 1.19

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/golang-jwt/jwt/v5 v5.0.0
    go.mongodb.org/mongo-driver v1.12.1
    golang.org/x/crypto v0.12.0
)
```

### Managing Dependencies

```bash
# Add a dependency
go get github.com/example/package

# Update dependencies
go get -u ./...

# Tidy (remove unused)
go mod tidy

# Verify checksums
go mod verify

# Vendor dependencies (optional)
go mod vendor
```

## Code Structure

### Entry Point (main.go)

```go
package main

import (
    "tasky/controllers"
    "tasky/database"
)

func main() {
    // Connect to MongoDB
    database.Connect()

    // Setup routes
    router := controllers.SetupRouter()

    // Start server
    router.Run(":8080")
}
```

### Database Connection

```go
// database/database.go
func Connect() {
    uri := os.Getenv("MONGODB_URI")
    client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
    // ...
}
```

### Authentication

```go
// auth/auth.go
func GenerateToken(userID string) (string, error) {
    secret := os.Getenv("JWT_SECRET")
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}
```

## Testing

### Run Tests

```bash
# All tests
go test ./...

# With coverage
go test -cover ./...

# Verbose
go test -v ./...

# Specific package
go test ./controllers/...
```

### Test with Race Detector

```bash
go test -race ./...
```

## Linting and Formatting

### Format Code

```bash
# Format all files
go fmt ./...

# Or use gofmt directly
gofmt -w .
```

### Lint with golangci-lint

```bash
# Install
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run
golangci-lint run
```

### Vet (Static Analysis)

```bash
go vet ./...
```

## Building for Container

The Dockerfile handles the build, but understanding the process:

```dockerfile
# Build stage
FROM golang:1.19 AS build
WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky
```

### Why CGO_ENABLED=0?

- Creates a **static binary** with no C library dependencies
- Required for Alpine Linux (uses musl, not glibc)
- Makes the binary portable across Linux distributions

### Why GOOS=linux GOARCH=amd64?

- Ensures consistent target platform
- Required when building on macOS/Windows for Linux containers
- `amd64` targets x86_64 architecture (standard for AWS EC2)

## Development Workflow

### Hot Reload with Air

```bash
# Install air
go install github.com/air-verse/air@latest

# Create config
air init

# Run with hot reload
air
```

### Debug with Delve

```bash
# Install delve
go install github.com/go-delve/delve/cmd/dlv@latest

# Debug
dlv debug main.go
```

## Build Artifacts

| Artifact | Location | Size |
|----------|----------|------|
| Binary | `./tasky` | ~10-15 MB |
| Container | Docker image | ~15-20 MB |

## Troubleshooting

### go mod download fails

```
go: module lookup disabled by GOPROXY=off
```

**Solution**: Check proxy settings:

```bash
go env GOPROXY
# Should be: https://proxy.golang.org,direct
```

### Build fails: package not found

```
cannot find package "github.com/..."
```

**Solution**: Download dependencies:

```bash
go mod download
go mod tidy
```

### Binary won't run on Linux

```
/lib/x86_64-linux-gnu/libc.so.6: version 'GLIBC_2.32' not found
```

**Solution**: Build with CGO disabled:

```bash
CGO_ENABLED=0 go build -o tasky
```

### Connection refused to MongoDB

**Solution**: Check MongoDB URI and network:

```bash
# Test connectivity
nc -zv localhost 27017

# Check environment variable
echo $MONGODB_URI
```

## Related Documentation

- [Container Build](container.md) - Dockerfile details
- [GitHub Actions](../reference/github-actions.md) - CI/CD pipeline
- [Environment Variables](../reference/environment.md) - Configuration

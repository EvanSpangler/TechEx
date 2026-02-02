# Local Development Setup

This guide explains how to set up and run the Tasky application locally for development.

## Prerequisites

### Required Software

| Tool | Version | Installation |
|------|---------|--------------|
| Go | 1.19+ | [golang.org/dl](https://golang.org/dl/) |
| Docker | 20.10+ | [docker.com](https://www.docker.com/get-started) |
| MongoDB | 4.4+ | Via Docker (recommended) |
| Git | 2.x | [git-scm.com](https://git-scm.com/) |

### Optional Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| VS Code | IDE | [code.visualstudio.com](https://code.visualstudio.com/) |
| Go extension | IDE support | VS Code marketplace |
| MongoDB Compass | DB GUI | [mongodb.com/compass](https://www.mongodb.com/products/compass) |
| Air | Hot reload | `go install github.com/cosmtrek/air@latest` |

## Quick Start

```bash
# Clone repository
git clone https://github.com/EvanSpangler/TechEx.git
cd TechEx/project/app

# Start MongoDB
docker run -d -p 27017:27017 --name mongodb mongo:4.4

# Create environment file
cat > .env << 'EOF'
MONGODB_URI=mongodb://localhost:27017/tasky
SECRET_KEY=local-dev-secret-do-not-use-in-production
PORT=8080
EOF

# Install dependencies
go mod download

# Run application
go run main.go
```

Application available at: http://localhost:8080

## Detailed Setup

### 1. Clone the Repository

```bash
# HTTPS
git clone https://github.com/EvanSpangler/TechEx.git

# SSH
git clone git@github.com:EvanSpangler/TechEx.git

# Navigate to app directory
cd TechEx/project/app
```

### 2. Start MongoDB

**Option A: Docker (Recommended)**

```bash
# Start MongoDB container
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -v mongodb-data:/data/db \
  mongo:4.4

# Verify it's running
docker ps | grep mongodb

# View logs if needed
docker logs mongodb
```

**Option B: Docker Compose**

Create `docker-compose.dev.yml`:

```yaml
version: '3.8'
services:
  mongodb:
    image: mongo:4.4
    ports:
      - "27017:27017"
    volumes:
      - mongodb-data:/data/db
    environment:
      MONGO_INITDB_DATABASE: tasky

volumes:
  mongodb-data:
```

Run:
```bash
docker-compose -f docker-compose.dev.yml up -d
```

**Option C: Local MongoDB Installation**

Follow [MongoDB installation guide](https://www.mongodb.com/docs/manual/installation/) for your OS.

### 3. Configure Environment

Create `.env` file in `project/app/`:

```bash
# Required
MONGODB_URI=mongodb://localhost:27017/tasky
SECRET_KEY=local-dev-secret-change-in-production

# Optional
PORT=8080
GIN_MODE=debug
```

| Variable | Description | Example |
|----------|-------------|---------|
| `MONGODB_URI` | MongoDB connection string | `mongodb://localhost:27017/tasky` |
| `SECRET_KEY` | JWT signing secret | Any random string |
| `PORT` | HTTP server port | `8080` |
| `GIN_MODE` | Gin mode (debug/release) | `debug` |

### 4. Install Dependencies

```bash
cd project/app

# Download dependencies
go mod download

# Verify dependencies
go mod verify

# Tidy up (removes unused)
go mod tidy
```

### 5. Run the Application

**Standard Run:**
```bash
go run main.go
```

**With Hot Reload (Air):**

Install Air:
```bash
go install github.com/cosmtrek/air@latest
```

Create `.air.toml`:
```toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ."
  bin = "./tmp/main"
  include_ext = ["go", "tpl", "tmpl", "html"]
  exclude_dir = ["assets", "tmp", "vendor"]
  delay = 1000

[log]
  time = false

[color]
  main = "magenta"
  watcher = "cyan"
  build = "yellow"
  runner = "green"
```

Run with hot reload:
```bash
air
```

### 6. Verify Installation

```bash
# Health check
curl http://localhost:8080/health
# Expected: {"app":"tasky","status":"healthy"}

# Wizexercise check
curl http://localhost:8080/wizexercise
# Expected: {"content":"...","status":"verified"}

# Test signup
curl -X POST http://localhost:8080/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'
```

## IDE Setup

### VS Code

**Recommended Extensions:**

1. **Go** (`golang.go`) - Official Go extension
2. **Go Test Explorer** - Test UI
3. **REST Client** - API testing
4. **Docker** - Container management

**settings.json:**
```json
{
  "go.useLanguageServer": true,
  "go.lintTool": "golangci-lint",
  "go.formatTool": "gofmt",
  "editor.formatOnSave": true,
  "[go]": {
    "editor.codeActionsOnSave": {
      "source.organizeImports": true
    }
  }
}
```

**launch.json (debugging):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Tasky",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "program": "${workspaceFolder}/project/app",
      "envFile": "${workspaceFolder}/project/app/.env"
    }
  ]
}
```

### GoLand

1. Open `project/app` as project
2. Configure Go SDK in Settings > Go > GOROOT
3. Enable Go Modules in Settings > Go > Go Modules
4. Set environment in Run Configuration

## Database Management

### MongoDB Compass

1. Download from [mongodb.com/compass](https://www.mongodb.com/products/compass)
2. Connect to `mongodb://localhost:27017`
3. Browse `tasky` database

### mongosh (CLI)

```bash
# Connect
docker exec -it mongodb mongosh

# Switch to database
use tasky

# List collections
show collections

# View users
db.user.find().pretty()

# View todos
db.todos.find().pretty()

# Clear test data
db.user.deleteMany({})
db.todos.deleteMany({})
```

## Running Tests

```bash
cd project/app

# Run all tests
go test ./...

# Verbose output
go test -v ./...

# With coverage
go test -cover ./...

# Specific package
go test -v ./controllers/...
```

## Building Container Locally

```bash
cd project/app

# Build image
docker build -t tasky:local .

# Run container
docker run -d \
  -p 8080:8080 \
  -e MONGODB_URI=mongodb://host.docker.internal:27017/tasky \
  -e SECRET_KEY=local-secret \
  --name tasky-local \
  tasky:local

# View logs
docker logs -f tasky-local

# Stop and remove
docker stop tasky-local && docker rm tasky-local
```

## Debugging

### Common Issues

#### "connection refused" to MongoDB

```bash
# Check MongoDB is running
docker ps | grep mongodb

# Start if not running
docker start mongodb

# Or recreate
docker rm -f mongodb
docker run -d -p 27017:27017 --name mongodb mongo:4.4
```

#### "SECRET_KEY not set"

```bash
# Ensure .env file exists
cat project/app/.env

# Or set directly
export SECRET_KEY=dev-secret
```

#### "module not found"

```bash
cd project/app
go mod download
go mod tidy
```

#### Port 8080 already in use

```bash
# Find process using port
lsof -i :8080

# Kill it or use different port
PORT=8081 go run main.go
```

### Enable Debug Logging

Set environment:
```bash
export GIN_MODE=debug
```

Or in code:
```go
gin.SetMode(gin.DebugMode)
```

### API Testing with curl

```bash
# Save cookies to file
curl -c cookies.txt -X POST http://localhost:8080/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"dev","email":"dev@test.com","password":"password"}'

# Use cookies for authenticated requests
curl -b cookies.txt http://localhost:8080/todos/<userid>
```

## Development Workflow

### Typical Development Cycle

1. **Start services:**
   ```bash
   docker start mongodb
   cd project/app && air
   ```

2. **Make code changes** - Air auto-reloads

3. **Test changes:**
   ```bash
   curl http://localhost:8080/your-endpoint
   # or
   go test ./...
   ```

4. **Check formatting:**
   ```bash
   go fmt ./...
   go vet ./...
   ```

5. **Commit:**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

### Pre-commit Checks

Before committing, run:
```bash
# Format code
go fmt ./...

# Run linter
golangci-lint run

# Run tests
go test ./...

# Build to check for errors
go build ./...
```

## Related Documentation

- [Application Architecture](application-architecture.md)
- [API Reference](../reference/api.md)
- [Application Testing](../testing/application-tests.md)
- [Container Build](../build/container.md)

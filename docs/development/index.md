# Development Guide

This section provides documentation for developers working on the Wiz Technical Exercise application.

## Overview

The Tasky application is a Go-based todo list application demonstrating a typical web application architecture with intentional security vulnerabilities for educational purposes.

## Quick Links

| Document | Description |
|----------|-------------|
| [Local Setup](local-setup.md) | Set up your development environment |
| [Application Architecture](application-architecture.md) | Understand the codebase structure |
| [API Reference](../reference/api.md) | Complete API documentation |
| [Application Testing](../testing/application-tests.md) | Testing guide |

## Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Go | 1.19+ |
| Web Framework | Gin | 1.9+ |
| Database | MongoDB | 4.4 |
| Authentication | JWT | - |
| Container Runtime | Docker | 20.10+ |
| Orchestration | Kubernetes (EKS) | 1.28+ |

## Getting Started

### 1. Prerequisites

```bash
# Verify Go installation
go version  # Should be 1.19+

# Verify Docker
docker --version  # Should be 20.10+

# Verify MongoDB access
docker run --rm mongo:4.4 mongod --version
```

### 2. Quick Start

```bash
# Clone repository
git clone https://github.com/EvanSpangler/TechEx.git
cd TechEx/project/app

# Start MongoDB
docker run -d -p 27017:27017 --name mongodb mongo:4.4

# Configure environment
cat > .env << 'EOF'
MONGODB_URI=mongodb://localhost:27017/tasky
SECRET_KEY=dev-secret-key
EOF

# Run application
go run main.go

# Test
curl http://localhost:8080/health
```

See [Local Setup](local-setup.md) for detailed instructions.

## Project Structure

```
project/app/
├── main.go              # Entry point, routes
├── controllers/         # HTTP handlers
│   ├── todoController.go
│   └── userController.go
├── models/              # Data structures
│   └── models.go
├── database/            # MongoDB connection
│   └── database.go
├── auth/                # JWT authentication
│   └── auth.go
├── assets/              # HTML templates
│   ├── login.html
│   └── todo.html
├── Dockerfile           # Container build
├── go.mod               # Dependencies
└── wizexercise.txt      # Exercise verification
```

See [Application Architecture](application-architecture.md) for detailed explanation.

## Development Workflow

### Standard Workflow

```bash
# 1. Start dependencies
docker start mongodb

# 2. Run application
cd project/app
go run main.go

# 3. Make changes (app auto-restarts if using Air)

# 4. Test
go test ./...

# 5. Format and lint
go fmt ./...
go vet ./...

# 6. Commit
git add .
git commit -m "feat: description"
```

### With Hot Reload

```bash
# Install Air
go install github.com/cosmtrek/air@latest

# Run with hot reload
cd project/app
air
```

## API Overview

| Endpoint | Method | Description | Auth |
|----------|--------|-------------|------|
| `/health` | GET | Health check | No |
| `/wizexercise` | GET | Exercise verification | No |
| `/signup` | POST | User registration | No |
| `/login` | POST | User authentication | No |
| `/todos/:userid` | GET | List user's todos | Yes |
| `/todo/:userid` | POST | Create todo | Yes |
| `/todo` | PUT | Update todo | Yes |
| `/todo/:userid/:id` | DELETE | Delete todo | Yes |

See [API Reference](../reference/api.md) for complete documentation.

## Testing

```bash
# Run all tests
go test ./...

# With coverage
go test -cover ./...

# Verbose output
go test -v ./...
```

See [Application Testing](../testing/application-tests.md) for complete testing guide.

## Building Container

```bash
# Build image
docker build -t tasky:dev app/

# Run locally
docker run -d \
  -p 8080:8080 \
  -e MONGODB_URI=mongodb://host.docker.internal:27017/tasky \
  -e SECRET_KEY=dev-secret \
  tasky:dev

# Verify
curl http://localhost:8080/health
curl http://localhost:8080/wizexercise
```

See [Container Build](../build/container.md) for deployment builds.

## Common Tasks

### Add a New Endpoint

1. Add handler function in appropriate controller
2. Register route in `main.go`
3. Add tests
4. Update API documentation

### Add a New Model

1. Define struct in `models/models.go`
2. Create controller if needed
3. Add database collection reference
4. Register routes

### Debug Authentication Issues

```bash
# Check JWT token
curl -c cookies.txt -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password"}'

# View cookies
cat cookies.txt

# Use token
curl -b cookies.txt http://localhost:8080/todos/<userid>
```

## Related Documentation

- [Local Setup](local-setup.md) - Detailed development environment setup
- [Application Architecture](application-architecture.md) - Code structure and patterns
- [API Reference](../reference/api.md) - Complete API documentation
- [Application Testing](../testing/application-tests.md) - Testing guide
- [Container Build](../build/container.md) - Building containers

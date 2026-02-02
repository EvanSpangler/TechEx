# Application Testing

This document covers testing for the Tasky Go application, including unit tests, integration tests, and container verification.

## Overview

The Tasky application is a Go-based todo app using the Gin web framework with MongoDB as the database. Testing focuses on:

- **Unit tests**: Individual function testing
- **Integration tests**: API endpoint testing
- **Container tests**: Verifying the built container image

## Application Structure

```
project/app/
├── main.go              # Application entry point, routes
├── controllers/
│   ├── todoController.go    # Todo CRUD operations
│   └── userController.go    # User auth operations
├── models/
│   └── models.go        # Data structures (Todo, User)
├── database/
│   └── database.go      # MongoDB connection
├── auth/
│   └── auth.go          # JWT authentication
├── assets/              # HTML templates
└── Dockerfile           # Container build
```

## Running Tests

### Go Unit Tests

```bash
cd project/app

# Run all tests
go test ./...

# Run with verbose output
go test -v ./...

# Run specific package
go test -v ./controllers/...

# Run with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### Container Testing

```bash
# Build and test container via Makefile
make test-container

# Manual container testing
cd project/app
docker build -t tasky:test .

# Verify wizexercise.txt exists
docker run --rm tasky:test cat /app/wizexercise.txt

# Run container and test health endpoint
docker run -d -p 8080:8080 --name tasky-test tasky:test
curl http://localhost:8080/health
docker stop tasky-test && docker rm tasky-test
```

## Test Categories

### Unit Tests

Unit tests verify individual functions in isolation.

#### Controller Tests Example

```go
// controllers/todoController_test.go
package controller

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
)

func TestGetTodo_NotFound(t *testing.T) {
    gin.SetMode(gin.TestMode)
    router := gin.Default()
    router.GET("/todo/:id", GetTodo)

    req, _ := http.NewRequest("GET", "/todo/invalid-id", nil)
    resp := httptest.NewRecorder()
    router.ServeHTTP(resp, req)

    assert.Equal(t, http.StatusInternalServerError, resp.Code)
}
```

#### Auth Tests Example

```go
// auth/auth_test.go
package auth

import (
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
)

func TestGenerateJWT(t *testing.T) {
    userID := "test-user-123"
    token, err, expTime := GenerateJWT(userID)

    assert.NoError(t, err)
    assert.NotEmpty(t, token)
    assert.True(t, expTime.After(time.Now()))
}

func TestValidateJWT(t *testing.T) {
    userID := "test-user-123"
    token, _, _ := GenerateJWT(userID)

    validatedToken, err := ValidateJWT(token)

    assert.NoError(t, err)
    assert.True(t, validatedToken.Valid)
}
```

### Integration Tests

Integration tests verify API endpoints with a test database.

#### Setup Test Database

```go
// test/setup_test.go
package test

import (
    "context"
    "testing"

    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

var testDB *mongo.Database

func setupTestDB(t *testing.T) {
    // Use test MongoDB instance
    client, err := mongo.Connect(context.Background(),
        options.Client().ApplyURI("mongodb://localhost:27017"))
    if err != nil {
        t.Fatal(err)
    }

    testDB = client.Database("tasky-test")
}

func teardownTestDB(t *testing.T) {
    testDB.Drop(context.Background())
}
```

#### API Integration Test Example

```go
// test/api_test.go
package test

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/stretchr/testify/assert"
)

func TestSignupLogin(t *testing.T) {
    setupTestDB(t)
    defer teardownTestDB(t)

    router := setupRouter()

    // Test signup
    user := map[string]string{
        "username": "testuser",
        "email":    "test@example.com",
        "password": "password123",
    }
    body, _ := json.Marshal(user)

    req, _ := http.NewRequest("POST", "/signup", bytes.NewBuffer(body))
    req.Header.Set("Content-Type", "application/json")
    resp := httptest.NewRecorder()

    router.ServeHTTP(resp, req)
    assert.Equal(t, http.StatusOK, resp.Code)

    // Test login
    loginReq, _ := http.NewRequest("POST", "/login", bytes.NewBuffer(body))
    loginReq.Header.Set("Content-Type", "application/json")
    loginResp := httptest.NewRecorder()

    router.ServeHTTP(loginResp, loginReq)
    assert.Equal(t, http.StatusOK, loginResp.Code)
}
```

### Container Tests

Container tests verify the built Docker image.

```bash
#!/bin/bash
# test/container_test.sh

set -e

IMAGE="tasky:test"

echo "Building container..."
docker build -t $IMAGE app/

echo "Testing wizexercise.txt exists..."
docker run --rm $IMAGE test -f /app/wizexercise.txt

echo "Testing health endpoint..."
CONTAINER_ID=$(docker run -d -p 8080:8080 $IMAGE)
sleep 3

HEALTH=$(curl -s http://localhost:8080/health | jq -r '.status')
if [ "$HEALTH" != "healthy" ]; then
    echo "Health check failed!"
    docker logs $CONTAINER_ID
    docker stop $CONTAINER_ID && docker rm $CONTAINER_ID
    exit 1
fi

echo "Testing wizexercise endpoint..."
WIZ=$(curl -s http://localhost:8080/wizexercise | jq -r '.status')
if [ "$WIZ" != "verified" ]; then
    echo "Wizexercise verification failed!"
    docker stop $CONTAINER_ID && docker rm $CONTAINER_ID
    exit 1
fi

echo "Cleanup..."
docker stop $CONTAINER_ID && docker rm $CONTAINER_ID

echo "All container tests passed!"
```

## Test Configuration

### Environment Variables for Testing

```bash
# .env.test
MONGODB_URI=mongodb://localhost:27017/tasky-test
SECRET_KEY=test-secret-key-do-not-use-in-production
PORT=8080
```

### Test Database with Docker Compose

```yaml
# docker-compose.test.yml
version: '3.8'
services:
  mongodb-test:
    image: mongo:4.4
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_DATABASE: tasky-test

  app-test:
    build: ./app
    environment:
      - MONGODB_URI=mongodb://mongodb-test:27017/tasky-test
      - SECRET_KEY=test-secret
    depends_on:
      - mongodb-test
    ports:
      - "8080:8080"
```

Run tests with:

```bash
docker-compose -f docker-compose.test.yml up -d
go test -v ./...
docker-compose -f docker-compose.test.yml down
```

## CI/CD Integration

Application tests run in the GitHub Actions workflow:

```yaml
# .github/workflows/test.yml (excerpt)
jobs:
  app-test:
    runs-on: ubuntu-latest
    services:
      mongodb:
        image: mongo:4.4
        ports:
          - 27017:27017
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'

      - name: Run unit tests
        working-directory: app
        env:
          MONGODB_URI: mongodb://localhost:27017/test
          SECRET_KEY: test-secret
        run: go test -v -cover ./...

  container-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build container
        run: docker build -t tasky:test app/

      - name: Verify wizexercise.txt
        run: docker run --rm tasky:test cat /app/wizexercise.txt

      - name: Test health endpoint
        run: |
          docker run -d -p 8080:8080 --name test tasky:test
          sleep 3
          curl -f http://localhost:8080/health
          docker stop test
```

## Test Coverage Requirements

| Package | Minimum Coverage |
|---------|-----------------|
| controllers | 60% |
| auth | 80% |
| models | 70% |
| database | 50% |

Generate and check coverage:

```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep total
```

## Troubleshooting

### "Connection refused" to MongoDB

```bash
# Ensure MongoDB is running
docker run -d -p 27017:27017 mongo:4.4

# Or check existing container
docker ps | grep mongo
```

### "SECRET_KEY not set"

```bash
# Set environment variable
export SECRET_KEY=test-secret-key

# Or use .env file
cp .env.example .env.test
```

### Container build fails

```bash
# Check Dockerfile syntax
docker build --no-cache -t tasky:debug app/

# View build logs
docker build -t tasky:debug app/ 2>&1 | tee build.log
```

## Related Documentation

- [Testing Overview](index.md)
- [Container Build](../build/container.md)
- [Application Architecture](../development/application-architecture.md)
- [Local Development](../development/local-setup.md)

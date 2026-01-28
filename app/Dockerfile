# Multi-stage build for Go tasky application
# Modified to include wizexercise.txt as required by Wiz exercise

# Build stage
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Release stage
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

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Run application
ENTRYPOINT ["/app/tasky"]

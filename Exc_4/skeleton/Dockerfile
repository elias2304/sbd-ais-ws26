# Stage 1: Build the application
FROM golang:1.27 AS builder

WORKDIR /app

# Copy all project contents into /app
COPY . .

# Ensure the build script is executable and run it
RUN chmod +x ./scripts/build-application.sh && \
    ./scripts/build-application.sh

# Stage 2: Runtime environment
FROM alpine:latest

WORKDIR /app

# Install ca-certificates in case the binary interacts with HTTPS endpoints
RUN apk --no-cache add ca-certificates

# Copy the compiled binary from the builder stage
COPY --from=builder /app/ordersystem /app/ordersystem

# Expose port if needed (uncomment and adjust if your app listens on a specific port)
# EXPOSE 8080

# Execute the application
ENTRYPOINT ["/app/ordersystem"]

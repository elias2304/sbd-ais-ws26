FROM golang:1.27 AS builder

WORKDIR /app

COPY . .

RUN sed -i 's/\r$//' ./scripts/build-application.sh && \
    chmod +x ./scripts/build-application.sh && \
    ./scripts/build-application.sh

FROM alpine:latest

WORKDIR /app

RUN apk --no-cache add ca-certificates

COPY --from=builder /app/ordersystem /app/ordersystem

EXPOSE 3000

ENTRYPOINT ["/app/ordersystem"]

FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .

RUN apk add --no-cache gcc musl-dev
RUN go mod download
RUN go build -o vpn-panel

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/vpn-panel .
COPY config ./config
COPY web ./web

RUN apk add --no-cache ca-certificates tzdata

EXPOSE 2053 443
CMD ["./vpn-panel"]

FROM golang:1.22-bookworm AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

FROM gcr.io/distroless/base-debian12

WORKDIR /app
COPY --from=builder /app/server .

ENV PORT=8080
EXPOSE 8080

CMD ["/app/server"]

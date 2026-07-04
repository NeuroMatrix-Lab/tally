FROM rust:latest-slim as builder

WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Install build dependencies required by crates that link OpenSSL
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/tally-server ./

ENV PORT=7378
ENV DATABASE_URL=mysql://user:password@localhost:3306/tally

EXPOSE 7378

CMD ["./tally-server"]

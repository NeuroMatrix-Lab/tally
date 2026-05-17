FROM rust:1.80-slim as builder

WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/tally-server ./

ENV PORT=7378
ENV DATABASE_URL=mysql://user:password@localhost:3306/tally

EXPOSE 7378

CMD ["./tally-server"]

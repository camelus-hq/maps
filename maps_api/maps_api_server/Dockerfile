# Build from the project root with:
# docker build -f maps_api_server/Dockerfile .

# Build stage
FROM dart:3.12.2 AS build

# The `ndk` dependency builds a Rust native library through Dart's native-assets
# build hooks (`dart build cli` runs them), so the build stage needs a Rust
# toolchain and a C compiler.
ARG RUST_VERSION=1.98.1
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --profile minimal --no-modify-path \
            --default-toolchain "${RUST_VERSION}"
# Use exactly the toolchain ndk pins in its rust-toolchain.toml, but skip that
# file's long cross-compilation target list: only the host target is built here.
ENV PATH="/root/.cargo/bin:${PATH}" \
    RUSTUP_TOOLCHAIN="${RUST_VERSION}"

# Create a minimal workspace that preserves locked server dependency versions.
WORKDIR /app
COPY pubspec.lock .
COPY maps_api_server maps_api_server
RUN printf '%s\n' \
  'name: _' \
  'environment:' \
  '  sdk: ^3.12.2' \
  'workspace:' \
  '  - maps_api_server' \
  > pubspec.yaml
RUN dart pub get

# Compile the server executable.
WORKDIR /app/maps_api_server
RUN dart build cli --target bin/main.dart --output build
RUN mv build/bundle/bin/main build/bundle/bin/server

# Add a fallback for the copy of possibly missing directories.
RUN mkdir -p config web migrations

# Final stage
FROM alpine:latest
WORKDIR /app

# Environment variables
ENV runmode=production
ENV serverid=default
ENV logging=normal
ENV role=monolith

# Copy runtime dependencies
COPY --from=build /runtime/ /

# Copy compiled server executable and native libraries
COPY --from=build /app/maps_api_server/build/bundle/ ./

# Copy configuration files and resources
COPY --from=build /app/maps_api_server/config/ config/
COPY --from=build /app/maps_api_server/web/ web/
COPY --from=build /app/maps_api_server/migrations/ migrations/

# This file is required to enable the endpoint log filter in Insights.
COPY --from=build /app/maps_api_server/lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml

# Expose ports
EXPOSE 8080
EXPOSE 8081
EXPOSE 8082

# Define the entrypoint command
ENTRYPOINT ./bin/server --mode=$runmode --server-id=$serverid --logging=$logging --role=$role

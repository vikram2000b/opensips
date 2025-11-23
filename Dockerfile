# Use Debian base image (supports ARM64 natively)
FROM debian:bookworm-slim

# Set OpenSIPS version
ENV OPENSIPS_VERSION=3.6.0

# Install build dependencies and runtime requirements
RUN apt-get update && \
    apt-get install -y \
    # Build tools
    gcc g++ make bison flex git wget pkg-config \
    # Runtime dependencies
    gettext-base ca-certificates \
    # OpenSIPS dependencies
    libmariadb-dev-compat libssl-dev libxml2-dev libpcre3-dev libncurses-dev \
    # Runtime libraries
    default-mysql-client libssl3 libxml2 libpcre3 && \
    # Download and build OpenSIPS
    cd /tmp && \
    wget https://github.com/OpenSIPS/opensips/archive/refs/tags/${OPENSIPS_VERSION}.tar.gz && \
    tar -xzf ${OPENSIPS_VERSION}.tar.gz && \
    cd opensips-${OPENSIPS_VERSION} && \
    # Compile OpenSIPS with required modules
    make include_modules="db_mysql tlsops presence" && \
    make install include_modules="db_mysql tlsops presence" && \
    # Clean up build dependencies and source
    cd / && \
    rm -rf /tmp/opensips-${OPENSIPS_VERSION} /tmp/${OPENSIPS_VERSION}.tar.gz && \
    apt-get purge -y gcc g++ make bison flex git wget pkg-config libmariadb-dev-compat libxml2-dev libpcre3-dev libncurses-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/run/opensips /var/log/opensips /etc/opensips

# Add OpenSIPS binaries to PATH
ENV PATH="/usr/local/sbin:${PATH}"

# Copy OpenSIPS configuration template
COPY config/opensips.cfg /etc/opensips/opensips.cfg.template

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SIP ports
EXPOSE 5060/udp
EXPOSE 5060/tcp

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]

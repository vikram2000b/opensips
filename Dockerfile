FROM opensips/opensips:3.4

# Install envsubst for variable substitution
RUN apt-get update && apt-get install -y --no-install-recommends gettext-base \
 && rm -rf /var/lib/apt/lists/*

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

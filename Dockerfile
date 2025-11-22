FROM opensips/opensips:3.4

# Copy OpenSIPS configuration
COPY config/opensips.cfg /etc/opensips/opensips.cfg

# Expose SIP ports
EXPOSE 5060/udp
EXPOSE 5060/tcp

# Run OpenSIPS in foreground
CMD ["opensips", "-f", "/etc/opensips/opensips.cfg", "-FE"]

#!/bin/bash
set -e

# Replace environment variables in config
envsubst < /etc/opensips/opensips.cfg.template > /etc/opensips/opensips.cfg

echo "OpenSIPS configuration generated with:"
echo "  MEDIA_SERVER_HOST: ${MEDIA_SERVER_HOST}"
echo "  MEDIA_SERVER_PORT: ${MEDIA_SERVER_PORT:-80}"

# Start OpenSIPS
exec opensips -f /etc/opensips/opensips.cfg -F

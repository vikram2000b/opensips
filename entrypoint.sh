#!/bin/bash
set -e

# Defaults for service and rtpengine targets
: "${MEDIA_SERVER_PORT:=5080}"
: "${RTPENGINE_HOST:=127.0.0.1}"
: "${RTPENGINE_PORT:=22222}"

# Replace ONLY our environment variables in config (not OpenSIPS script variables)
envsubst '${MEDIA_SERVER_HOST} ${MEDIA_SERVER_PORT} ${RTPENGINE_HOST} ${RTPENGINE_PORT}' < /etc/opensips/opensips.cfg.template > /etc/opensips/opensips.cfg

echo "OpenSIPS configuration generated with:"
echo "  MEDIA_SERVER_HOST: ${MEDIA_SERVER_HOST}"
echo "  MEDIA_SERVER_PORT: ${MEDIA_SERVER_PORT}"
echo "  RTPENGINE_HOST: ${RTPENGINE_HOST}"
echo "  RTPENGINE_PORT: ${RTPENGINE_PORT}"

# Start OpenSIPS
exec opensips -f /etc/opensips/opensips.cfg -F -m 128

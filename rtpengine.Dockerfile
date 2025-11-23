# Runtime-only rtpengine (userspace) build for local testing
# Note: built for amd64; adjust build args if targeting a different arch.
FROM fonoster/rtpengine:latest

EXPOSE 22222/udp 40000-41000/udp

ENTRYPOINT ["/usr/bin/rtpengine"]
CMD ["--foreground", "--listen-ng=0.0.0.0:22222", "--listen-cli=0.0.0.0:2224", "--listen-http=0.0.0.0:2225", "--log-level=6", "--interface=public/eth0", "--interface=webrtc/eth0", "--port-min=40000", "--port-max=41000"]

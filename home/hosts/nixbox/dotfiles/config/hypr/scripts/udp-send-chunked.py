#!/usr/bin/env python3
"""
Read raw bytes from stdin and send them in fixed-size UDP packets to host:port.
Smaller chunks = lower latency. 256 bytes = ~1.3ms at 48k stereo (practical floor).
"""

import sys
import socket

CHUNK = 256  # 64 frames @ 48k stereo = ~1.3ms; lowest sensible without constant dropouts
if len(sys.argv) != 3:
    print("Usage: udp-send-chunked.py <host> <port>", file=sys.stderr)
    sys.exit(1)
host, port = sys.argv[1], int(sys.argv[2])
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    while True:
        data = sys.stdin.buffer.read(CHUNK)
        if not data:
            break
        sock.sendto(data, (host, port))
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    sock.close()

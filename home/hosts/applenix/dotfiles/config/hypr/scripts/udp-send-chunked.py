#!/usr/bin/env python3
"""
Read raw PCM from stdin and send fixed-size UDP datagrams.

Stdin must be s16le stereo @ 48 kHz (192000 byte/s), no headers. FFmpeg is
usually bursty; we pace sends slightly above nominal rate (~1%) so packets
stay slightly ahead of playback (absorbs sleep/timer jitter on the sender).
"""

import sys
import socket
import time

# 20 ms @ 48 kHz stereo s16le (must be multiple of 4)
CHUNK = 3840
READ_SIZE = 64 * 1024
FRAME_ALIGN = 4
BYTE_RATE = 48000 * 2 * 2  # 192000 B/s nominal stream
# Pace ~1.2% faster than nominal so bursty stdin/sleep jitter doesn’t starve the Mac buffer
PACING_RATE = BYTE_RATE * 1.012
CHUNK_PERIOD = CHUNK / PACING_RATE

if len(sys.argv) != 3:
    print("Usage: udp-send-chunked.py <host> <port>", file=sys.stderr)
    sys.exit(1)
host, port = sys.argv[1], int(sys.argv[2])
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 4 * 1024 * 1024)
except OSError:
    pass

buf = bytearray()
last_send_mono = time.monotonic()


def send_one_chunk():
    global last_send_mono
    sock.sendto(memoryview(buf)[:CHUNK], (host, port))
    del buf[:CHUNK]
    now = time.monotonic()
    elapsed = now - last_send_mono
    last_send_mono = now
    wait = CHUNK_PERIOD - elapsed
    if wait > 0:
        time.sleep(wait)


try:
    while True:
        blob = sys.stdin.buffer.read(READ_SIZE)
        if not blob:
            break
        buf.extend(blob)
        while len(buf) >= CHUNK:
            send_one_chunk()
    if buf:
        n = (len(buf) // FRAME_ALIGN) * FRAME_ALIGN
        if n:
            sock.sendto(memoryview(buf)[:n], (host, port))
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    sock.close()

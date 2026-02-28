#!/usr/bin/env python3
"""
Receive raw s16le 48kHz stereo UDP stream (from NixOS audio-transmit.sh) and
play to BlackHole (or default output). Run on your Mac.

Usage: python3 receive_audio_mac.py [port]
  Default port: 49152

Requires: pip3 install sounddevice
"""

import socket
import sys
import threading
import queue
import time

try:
    import sounddevice as sd
    import numpy as np
except ImportError as e:
    print("Install: pip3 install sounddevice numpy", file=sys.stderr)
    sys.exit(1)

PORT = 49152
RATE = 48000
CHANNELS = 2
DTYPE = "int16"
CHUNK_FRAMES = 64    # ~1.3ms per block; practical floor (smaller = dropouts on jitter)
BYTES_PER_FRAME = CHANNELS * 2  # s16le = 2 bytes per sample
MAX_QUEUE = 4       # ~5ms buffer; lowest sensible without glitches


def find_blackhole():
    """Use BlackHole as output if present, else default."""
    devs = sd.query_devices()
    for i, d in enumerate(devs):
        if d["max_output_channels"] > 0 and "blackhole" in d["name"].lower():
            return i
    return None


def make_callback(q):
    def cb(outdata, frames, time_info, status):
        if status:
            print(status, file=sys.stderr)
        try:
            block = q.get_nowait()
        except queue.Empty:
            outdata.fill(0)
            return
        n = min(len(block) // BYTES_PER_FRAME, frames)
        if n > 0:
            outdata[:n] = np.frombuffer(
                block[: n * BYTES_PER_FRAME], dtype=np.int16
            ).reshape(n, CHANNELS)
        if n < frames:
            outdata[n:] = 0

    return cb


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    dev = find_blackhole()
    if dev is not None:
        print(f"Playing to: {sd.query_devices(dev)['name']}", file=sys.stderr)
    else:
        dev = None
        print("BlackHole not found, using default output.", file=sys.stderr)

    q = queue.Queue(maxsize=MAX_QUEUE)
    closed = threading.Event()

    def recv_loop():
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind(("0.0.0.0", port))
        except OSError as e:
            print(f"Bind failed: {e}. Port {port} in use?", file=sys.stderr)
            closed.set()
            return
        sock.settimeout(1.0)
        print(
            f"Listening on UDP port {port}. Start the NixOS transmitter.",
            file=sys.stderr,
        )
        while not closed.is_set():
            try:
                data, _ = sock.recvfrom(CHUNK_FRAMES * BYTES_PER_FRAME * 2)
                if not data:
                    break
                try:
                    q.put_nowait(data)
                except queue.Full:
                    q.get_nowait()
                    q.put_nowait(data)
            except socket.timeout:
                continue
            except Exception:
                break
        sock.close()

    t = threading.Thread(target=recv_loop, daemon=True)
    t.start()

    try:
        with sd.OutputStream(
            device=dev,
            samplerate=RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            blocksize=CHUNK_FRAMES,
            callback=make_callback(q),
        ):
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        closed.set()


if __name__ == "__main__":
    main()

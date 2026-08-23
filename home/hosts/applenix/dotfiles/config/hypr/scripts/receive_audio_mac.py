#!/usr/bin/env python3
"""
Receive raw s16le 48kHz stereo UDP stream (from NixOS audio-transmit.sh) and
play to BlackHole (or default output). Run on your Mac.

Wire format (each datagram payload):
  - Raw PCM little-endian signed 16-bit
  - Interleaved stereo (L, R, L, R, …)
  - 48000 frames/s → 192000 byte/s sustained (960 frames = 3840 bytes / 20 ms)

No WAV/header bytes; payload length should be a multiple of 4.

Usage: python3 receive_audio_mac.py [port]
  Default port: 49152

Requires: pip3 install sounddevice
"""

import socket
import sys
import threading
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
BYTES_PER_FRAME = CHANNELS * 2  # s16le stereo
BYTES_PER_SEC = RATE * BYTES_PER_FRAME  # 192000

# 20 ms @ 48k stereo — matches udp-send-chunked CHUNK (3840 B)
OUTPUT_BLOCK_FRAMES = 960
RECV_MAX = 65507

# Wider window: fewer trims + more headroom before underrun (~35 ms extra latency)
BUF_LOW_MS = 150
BUF_HIGH_MS = 340
BUF_LOW_BYTES = int(BYTES_PER_SEC * BUF_LOW_MS / 1000)
BUF_HIGH_BYTES = int(BYTES_PER_SEC * BUF_HIGH_MS / 1000)
PRIME_BYTES = int(BYTES_PER_SEC * 100 / 1000)
OUTPUT_LATENCY = 0.14


class ByteFIFO:
    """FIFO of PCM bytes; avoid shifting the whole buffer on every consume."""

    __slots__ = ("_buf", "_off")

    def __init__(self):
        self._buf = bytearray()
        self._off = 0

    def __len__(self):
        return len(self._buf) - self._off

    def extend(self, data):
        self._buf.extend(data)

    def _compact(self):
        if self._off > 262144 or (
            self._off > 4096 and self._off * 2 > len(self._buf)
        ):
            del self._buf[: self._off]
            self._off = 0

    def take(self, n: int):
        if len(self) < n:
            return None
        start = self._off
        self._off += n
        chunk = bytes(memoryview(self._buf)[start : self._off])
        self._compact()
        return chunk

    def trim_if_over(self, high_bytes: int, keep_bytes: int):
        L = len(self)
        if L <= high_bytes:
            return
        drop = L - keep_bytes
        drop = (drop // BYTES_PER_FRAME) * BYTES_PER_FRAME
        if drop <= 0:
            return
        self._off += drop
        self._compact()


def find_blackhole():
    """Use BlackHole as output if present, else default."""
    devs = sd.query_devices()
    for i, d in enumerate(devs):
        if d["max_output_channels"] > 0 and "blackhole" in d["name"].lower():
            return i
    return None


def make_callback(fifo: ByteFIFO, pcm_lock: threading.Lock):
    def cb(outdata, frames, time_info, status):
        if status:
            ign = getattr(sd.CallbackFlags, "priming_output", 0)
            if int(status) & ~int(ign):
                print(status, file=sys.stderr)
        need = frames * BYTES_PER_FRAME
        with pcm_lock:
            chunk = fifo.take(need)
        if chunk is None:
            outdata.fill(0)
            return
        outdata[:] = np.frombuffer(chunk, dtype=np.int16).reshape(frames, CHANNELS)

    return cb


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    dev = find_blackhole()
    if dev is not None:
        print(f"Playing to: {sd.query_devices(dev)['name']}", file=sys.stderr)
    else:
        dev = None
        print("BlackHole not found, using default output.", file=sys.stderr)

    print(
        "UDP payload must be raw s16le stereo 48 kHz interleaved, no headers "
        f"(~{BYTES_PER_SEC} byte/s). Datagram lengths should be multiples of 4.",
        file=sys.stderr,
    )

    fifo = ByteFIFO()
    pcm_lock = threading.Lock()
    closed = threading.Event()

    def recv_loop():
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
        except OSError:
            pass
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
                data, _ = sock.recvfrom(RECV_MAX)
                if not data:
                    break
                if len(data) % BYTES_PER_FRAME != 0:
                    continue
                with pcm_lock:
                    fifo.extend(data)
                    fifo.trim_if_over(BUF_HIGH_BYTES, BUF_LOW_BYTES)
            except socket.timeout:
                continue
            except Exception:
                break
        sock.close()

    t = threading.Thread(target=recv_loop, daemon=True)
    t.start()

    t_end = time.monotonic() + 0.4
    while time.monotonic() < t_end and not closed.is_set():
        with pcm_lock:
            if len(fifo) >= PRIME_BYTES:
                break
        time.sleep(0.01)

    try:
        with sd.OutputStream(
            device=dev,
            samplerate=RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            blocksize=OUTPUT_BLOCK_FRAMES,
            latency=OUTPUT_LATENCY,
            callback=make_callback(fifo, pcm_lock),
        ):
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        closed.set()


if __name__ == "__main__":
    main()

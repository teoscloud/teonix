# Receiving NixOS audio on macOS (plain UDP)

Your NixOS script sends **stereo 48 kHz s16le** PCM to `<mac_ip>:49152` (default port).

**Hyprland shortcuts (nixbox):** `Super+Shift+L` toggles **SSH** stream (Mac receiver on `127.0.0.1`; socat on Mac). `Super+Shift+;` toggles **UDP** to the Mac’s LAN IP (receiver must listen on `0.0.0.0:49152`, e.g. `receive_audio_mac.py` — not localhost-only). Only one mode runs at a time; starting one stops the other.

## 1. Quick test (default output)

If you just want to hear it and your Mac’s **default output** is already BlackHole (or you temporarily set it to BlackHole):

```bash
# Install ffmpeg if needed: brew install ffmpeg
ffplay -f s16le -ar 48000 -ac 2 -nodisp -i udp://0.0.0.0:49152
```

Then on NixOS run: `~/.config/hypr/scripts/audio-transmit.sh <your_mac_ip> 49152`

---

## 2. Receive and play to BlackHole (for Aggregate Device)

So the stream always goes to **BlackHole** (and then into your Aggregate Device / FL Studio), use the Python receiver below.

### One-time setup on Mac

```bash
brew install python@3.12
pip3 install sounddevice numpy
```

Install **BlackHole** 2ch: https://existential.audio/blackhole/

### Run the receiver

1. Start the receiver first (it will listen on UDP 49152 and play to BlackHole):

```bash
python3 receive_audio_mac.py
```

2. On NixOS, run the transmitter:

```bash
~/.config/hypr/scripts/audio-transmit.sh <your_mac_ip> 49152
```

3. In **Audio MIDI Setup**, add BlackHole to an **Aggregate Device**. In **FL Studio**, select that Aggregate Device; the NixOS input will be BlackHole’s channels.

---

## Encrypted (SSH)

Same receiver; no changes on the Mac except **Remote Login** on and **key-based SSH** from NixOS. On NixOS:

```bash
~/.config/hypr/scripts/audio-transmit.sh --ssh teodorstan@192.168.0.93 49152
```

Start the receiver on the Mac first (`python3 receive_audio_mac.py`). On the Mac you need `socat` for the tunnel: `brew install socat`.

**Latency:** SSH uses TCP, which buffers data and adds delay. For **lowest latency** use **plain UDP** on a trusted LAN; use SSH when you need encryption and can accept extra delay. You can try in `~/.ssh/config` on NixOS to ask the OS for low-delay treatment (may help a little):

```
Host 192.168.0.93
  Compression no
  IPQoS lowdelay
```

---

## Optional: change port

Same port on both sides. Default is **49152**. To use e.g. 50000:

- Mac: `python3 receive_audio_mac.py 50000`
- NixOS: `~/.config/hypr/scripts/audio-transmit.sh <mac_ip> 50000`

---

## Mac not getting any packets

1. **macOS firewall** – Most common. Allow the receiver:
   - **System Settings → Network → Firewall** (or **Security & Privacy → Firewall**).
   - Either turn the firewall off temporarily to test, or add an rule to allow **Python** (or your terminal app) **incoming**.
   - Or: **Firewall Options → +** and add your Python app / allow incoming for the app that runs the receiver.

2. **Check that packets reach the Mac** with netcat (no tcpdump needed):
   - **On Mac:** listen for UDP (use one of these, depending on your `nc`):
     ```bash
     nc -u -l 49152
     ```
     or if that fails: `ncat -u -l 49152` (install with `brew install nmap` if needed).
   - **On NixOS:** run the transmitter (or send a single test packet):
     ```bash
     echo "test" | nc -u 192.168.0.97 49152
     ```
     Replace `192.168.0.97` with your Mac’s IP. If the Mac’s `nc` prints `test` (or any output), the path is open. Then run the real transmitter; you should see a stream of binary data on the Mac. If the Mac gets nothing, the Mac firewall or network is blocking.

3. **Check that NixOS is sending:** Run the transmitter on NixOS. On the Mac, run `nc -u -l 49152` (or `ncat -u -l 49152`). If binary data appears on the Mac, NixOS is sending and the problem is only in the Python receiver. If still nothing, see step 1 (firewall) and step 4 (IP).

4. **Correct Mac IP** – On the Mac run `ipconfig getifaddr en0` (Wi‑Fi) or check **System Settings → Network**. Use that IP from NixOS. Ping from NixOS: `ping -c 1 192.168.0.97`.

5. The transmitter now sends a small **probe packet** as soon as you run it. If the Mac receives that, the path is open and the rest is the audio stream.

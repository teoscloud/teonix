#!/usr/bin/env bash

# Mic name (change only if needed)
MIC_NAME="alsa_input.pci-0000_0d_00.4.analog-stereo"

# Check if loopback module is already loaded
LOADED_ID=$(pactl list short modules | grep "module-loopback" | grep "$MIC_NAME" | awk '{print $1}')

if [ -n "$LOADED_ID" ]; then
  pactl unload-module "$LOADED_ID"
  notify-send "🎙️ Mic Monitor" "Monitoring OFF"
else
  pactl load-module module-loopback source=$MIC_NAME
  notify-send "🎙️ Mic Monitor" "Monitoring ON"
fi

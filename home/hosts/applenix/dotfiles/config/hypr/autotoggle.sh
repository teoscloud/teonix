#!/bin/bash

while true; do
    active_window_class=$(hyprctl activewindow | grep "class:" | awk '{print $2}')
    if [[ "$active_window_class" == ".qemu-system-x86_64-wrapped" ]]; then
        sh /home/teodor/.config/hypr/togglescale.sh
    fi
    sleep 1 # Adjust the sleep interval as needed
done

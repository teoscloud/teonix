#!/bin/bash

# Get the currently focused monitor
current_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

# Get the list of unfocused monitors
unfocused_monitors=$(hyprctl monitors -j | jq -r --arg current_monitor "$current_monitor" '.[] | select(.name != $current_monitor) | .name')

# Convert unfocused monitors to an array
unfocused_monitor_array=($unfocused_monitors)

# Check if there are any unfocused monitors
if [ ${#unfocused_monitor_array[@]} -eq 0 ]; then
  echo "No unfocused monitors found."
  exit 1
fi

# Pick the first unfocused monitor
next_monitor=${unfocused_monitor_array[0]}

# Get the workspace with windows on the next monitor (this indicates the active workspace)
next_workspace=$(hyprctl workspaces -j | jq -r --arg monitor "$next_monitor" '.[] | select(.monitor == $monitor and .windows > 0) | .id')

# If no workspace with windows is found, fallback to the first workspace on that monitor
if [ -z "$next_workspace" ]; then
  echo "No active workspace with windows found on monitor: $next_monitor. Selecting the first available workspace."
  next_workspace=$(hyprctl workspaces -j | jq -r --arg monitor "$next_monitor" '.[] | select(.monitor == $monitor) | .id' | head -n 1)
fi

# Output the monitor and workspace information
echo "Switching to monitor: $next_monitor, workspace: $next_workspace"

# Switch to the next workspace on the next monitor
#hyprctl dispatch workspace "$next_workspace"
hyprctl dispatch focusmonitor "$next_monitor"

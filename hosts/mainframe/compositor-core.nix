{ config, pkgs, lib, ... }:

# Dedicated compositor core for Hyprland.
#
# Hyprland renders every output from one thread. Measured on this box that thread
# sits at 60-90% of a 3 GHz Broadwell core with the desktop busy (one full pass
# per vblank across three outputs, ~700 wakeups/s), most of it in the kernel on
# the GPU's ioctls — and the scheduler happily parks it on the *other* socket from
# the Arc. Every time it is preempted, migrated, or waits for a core to leave C6,
# a frame is late and the cursor stutters. So: give that thread a physical core
# nobody else may touch, on the GPU's socket, that never sleeps deep and never
# clocks down, with the GPU's interrupt landing on its hyperthread sibling.
#
#   CPU 2 + its HT sibling 30, both NUMA node 0 (0-13,28-41), same socket as the
#   Arc's IRQ. Verify with
#     cat /sys/devices/system/cpu/cpu2/topology/thread_siblings_list   -> 2,30
#     cat /sys/devices/system/node/node0/cpulist                        -> 0-13,28-41
#
# Three fences, so nothing else ever runs there:
#   kernel   isolcpus removes 2,30 from the scheduler domains, nohz_full/rcu_nocbs
#            stop the tick and RCU callbacks on them, irqaffinity keeps device
#            interrupts off them by default.
#   cgroups  system.slice and the user app/background slices carry a cpuset that
#            excludes 2,30 — a cpuset overrides inherited affinity, so anything
#            UWSM launches into app-graphical.slice is forced off the core even if
#            it forked from the compositor.
#   unit     the UWSM compositor unit (wayland-wm@hyprland.desktop.service, session.slice)
#            is pinned to 2,30 with memory bound to node 0.
#
# Requires the "Hyprland (UWSM)" session (programs.hyprland.withUWSM in
# modules/apps/programs.nix): only then is the compositor a systemd unit this can
# pin, and only then do exec-once children land in their own scopes.
#
# Rollback: pick the plain "Hyprland" session in GDM or boot the previous
# generation. An isolated core with nothing pinned to it simply idles.
# See GPU.md, "Compositor core".

let
  coreCpus = "2,30"; # CPUAffinity syntax below wants "2 30"
  otherCpus = "0-1,3-29,31-55";
  gpuNode = "0";

  reserveCore = pkgs.writeShellScript "teonix-compositor-core" ''
    set -u
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.gawk ]}

    log() { echo "teonix-compositor-core: $*"; }

    for cpu in ${lib.replaceStrings [ "," ] [ " " ] coreCpus}; do
      base=/sys/devices/system/cpu/cpu$cpu

      # Never clock down: the render thread's work is bursty (one pass per
      # vblank) and schedutil ramps too slowly for a 4 ms frame budget.
      gov=$base/cpufreq/scaling_governor
      if [ -w "$gov" ] && grep -qw performance "$base/cpufreq/scaling_available_governors"; then
        echo performance > "$gov" && log "cpu$cpu governor performance"
      else
        log "cpu$cpu: performance governor unavailable"
      fi

      # Never sleep deep: C6 exit is ~133 us here, a tenth of the 240 Hz frame.
      # C1/C1E/C3 stay enabled; the core still idles between frames.
      for st in "$base"/cpuidle/state*; do
        [ -r "$st/name" ] || continue
        case "$(cat "$st/name")" in
          C6*) echo 1 > "$st/disable" && log "cpu$cpu $(cat "$st/name") disabled" ;;
        esac
      done
    done

    # GPU interrupt (vblank, flip done) on the render thread's HT sibling, so
    # completion wakes it from the same core without a cross-socket IPI.
    sibling=$(cut -d, -f2 /sys/devices/system/cpu/cpu${lib.head (lib.splitString "," coreCpus)}/topology/thread_siblings_list)
    [ -n "$sibling" ] || sibling=${lib.last (lib.splitString "," coreCpus)}
    found=0
    for irq in $(awk -F: '/(i915|xe|amdgpu)/ { gsub(/ /, "", $1); print $1 }' /proc/interrupts); do
      if echo "$sibling" > /proc/irq/$irq/smp_affinity_list 2>/dev/null; then
        log "gpu irq $irq -> cpu$sibling"
        found=1
      else
        log "gpu irq $irq: could not set affinity"
      fi
    done
    [ "$found" = 1 ] || log "no GPU irq found in /proc/interrupts"
  '';
in
{
  boot.kernelParams = [
    # domain: out of the scheduler domains (only explicit affinity lands there).
    # managed_irq: managed device queues avoid these CPUs too.
    "isolcpus=domain,managed_irq,${coreCpus}"
    # No scheduler tick / RCU callbacks on the core while a single task runs.
    "nohz_full=${coreCpus}"
    "rcu_nocbs=${coreCpus}"
    # Default affinity for every other interrupt; the oneshot then places the
    # GPU's on the sibling explicitly.
    "irqaffinity=${otherCpus}"
    # PREEMPT_DYNAMIC kernel: full preemption cuts wakeup-to-run latency for the
    # SCHED_RR compositor thread. Minor throughput cost, chosen on purpose.
    "preempt=full"
  ];

  systemd.services.teonix-compositor-core = {
    description = "Reserve the compositor core: governor, C-states, GPU IRQ placement";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" "cpufreq.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = reserveCore;
    };
  };
  # Firmware may reset governor / C-state masks across S3/S4; re-apply.
  powerManagement.resumeCommands = "${reserveCore}";

  # Daemons off the core.
  systemd.slices.system = {
    overrideStrategy = "asDropin";
    sliceConfig.AllowedCPUs = otherCpus;
  };

  # The user manager gets the cpuset controller (default is only cpu memory pids),
  # or the user-slice cpusets below are silently ignored.
  systemd.services."user@" = {
    overrideStrategy = "asDropin";
    serviceConfig.Delegate = "pids memory cpu cpuset";
  };

  # Apps and background services off the core. session.slice (the compositor,
  # PipeWire) stays unrestricted.
  systemd.user.slices.app = {
    overrideStrategy = "asDropin";
    sliceConfig.AllowedCPUs = otherCpus;
  };
  systemd.user.slices.background = {
    overrideStrategy = "asDropin";
    sliceConfig.AllowedCPUs = otherCpus;
  };

  # The compositor itself. The NixOS session entry runs
  # `uwsm start -e -D Hyprland hyprland.desktop`, and UWSM names the unit after
  # its main argument: wayland-wm@hyprland.desktop.service (see
  # /run/current-system/sw/share/wayland-sessions/hyprland-uwsm.desktop; a hand
  # `uwsm start Hyprland` would be wayland-wm@Hyprland.service instead).
  systemd.user.services."wayland-wm@hyprland.desktop" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      CPUAffinity = lib.replaceStrings [ "," ] [ " " ] coreCpus;
      NUMAPolicy = "bind";
      NUMAMask = gpuNode;
    };
  };
}

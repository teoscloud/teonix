pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    property bool mixerOpen: false
    property bool notifDrawerOpen: false
    property bool powerMenuOpen: false
    property bool startMenuOpen: false
    property var pinnedApps: []
    property bool launcherOpen: false
    property bool emojiOpen: false
    property int notifCount: 0
    property int toplevelEpoch: 0
    // Live scrolling-layout geometry from hyprctl (QS lastIpcObject.at is often stale).
    property var layoutByAddr: ({})
    property int layoutEpoch: 0
    property string layoutSig: ""
    property bool ctxMenuOpen: false
    property var ctxMenuItems: []
    property real ctxMenuX: 80
    property real ctxMenuY: 80
    // Window to receive insert/paste after overlays close (Hyprland address 0x…)
    property string insertTargetAddress: ""

    // Bar + dock only on this Hyprland output (hyprctl monitors).
    // Prefer the laptop panel when present (Asahi Mac), else the usual
    // nixbox primary — so one mainframe tree serves both hosts.
    readonly property string shellMonitor: {
        const list = Quickshell.screens;
        const prefer = ["eDP-1", "DP-1", "HDMI-A-1"];
        for (let p = 0; p < prefer.length; p++) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].name === prefer[p])
                    return prefer[p];
            }
        }
        return list.length ? list[0].name : "eDP-1";
    }

    function isShellMonitor(screen) {
        return !!(screen && screen.name === shellMonitor);
    }

    // Overlays have to be pinned to the bars' output; an unbound PanelWindow
    // picks a screen on its own and lands on the wrong monitor.
    property var boundShellScreen: null

    readonly property var shellScreen: {
        if (boundShellScreen)
            return boundShellScreen;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === shellMonitor)
                return list[i];
        }
        return null;
    }

    function bindShellScreen(screen) {
        if (screen && screen.name === shellMonitor)
            boundShellScreen = screen;
    }

    // Layer surfaces with ExclusionMode.Ignore cover the rail; lift popups
    // by this much so they sit on the plate, not inside it.
    readonly property int overlayLift: 8

    // Wallpaper-derived glass tint (overlays only — not bar/dock)
    property real wallR: 0.12
    property real wallG: 0.12
    property real wallB: 0.14
    property string wallPath: ""
    // 0 = dark base only, 1 = pure wallpaper tint
    property real wallStrength: 0.68

    // Resolve against the active shell tree (works with qs -p and HM symlink)
    readonly property string buschainWaybar: Quickshell.shellPath("scripts/qs-buschain-waybar.sh")
    readonly property string buschainCtl: Quickshell.shellPath("scripts/qs-buschain-ctl.sh")
    readonly property string wallpaperTintScript: Quickshell.shellPath("scripts/qs-wallpaper-tint.py")
    readonly property string sysStatsScript: Quickshell.shellPath("scripts/qs-sys-stats.py")
    readonly property string mprisArtScript: Quickshell.shellPath("scripts/qs-mpris-art.py")
    readonly property string mixerTickPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/buschain-control/mixer.tick`

    property int cpuPct: 0
    property int ramPct: 0
    property string netRx: "0B"
    property string netTx: "0B"

    // Shared Master HW status for VolumePill / ScrollStrip
    property int hwVolPct: 0
    property bool hwVolMuted: false
    property bool hwVolOnline: false
    property int hwVolEpoch: 0

    // VolumePill geometry (updated from Bar.qml) — strip + mixer anchor
    property string volStripAnchor: "left"
    property int volStripMarginX: 120
    property int volStripWidth: 110
    property int volPillX: 120
    property int volPillWidth: 64
    // ScrollStrip sits above the bar; forward hover so the pill can gray
    property bool volStripHovered: false

    function bumpHwVol() {
        hwVolEpoch++;
    }

    function normAddr(addr) {
        if (addr === undefined || addr === null || addr === "")
            return "";
        let s = String(addr).trim();
        if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0)
            return s.toLowerCase();
        if (/^[0-9]+$/.test(s))
            return "0x" + Number(s).toString(16);
        if (/^[0-9a-fA-F]+$/.test(s))
            return "0x" + s.toLowerCase();
        return s.toLowerCase();
    }

    function ingestClientsJson(text) {
        const raw = String(text || "").trim();
        if (!raw || raw.charAt(0) !== "[")
            return;
        try {
            const arr = JSON.parse(raw);
            if (!Array.isArray(arr))
                return;
            const map = {};
            for (let i = 0; i < arr.length; i++) {
                const c = arr[i];
                if (!c || c.mapped === false)
                    continue;
                const a = normAddr(c.address);
                if (!a)
                    continue;
                const at = c.at;
                let x = 0, y = 0;
                if (Array.isArray(at) && at.length >= 1) {
                    x = Number(at[0]) || 0;
                    y = Number(at[1]) || 0;
                } else if (at && typeof at === "object") {
                    x = Number(at.x ?? at[0]) || 0;
                    y = Number(at.y ?? at[1]) || 0;
                }
                const ws = c.workspace;
                let wid = -1;
                if (typeof ws === "number")
                    wid = Number(ws);
                else if (ws && typeof ws === "object")
                    wid = Number(ws.id ?? -1);
                const sz = c.size;
                let w = 0, h = 0;
                if (Array.isArray(sz) && sz.length >= 2) {
                    w = Number(sz[0]) || 0;
                    h = Number(sz[1]) || 0;
                } else if (sz && typeof sz === "object") {
                    w = Number(sz.w ?? sz.x ?? sz[0]) || 0;
                    h = Number(sz.h ?? sz.y ?? sz[1]) || 0;
                }
                map[a] = {
                    address: a,
                    x: x,
                    y: y,
                    w: w,
                    h: h,
                    floating: !!c.floating,
                    workspace: wid,
                    fullscreen: Number(c.fullscreen) > 0,
                    visible: c.visible !== false,
                    className: String(c.class || c.initialClass || ""),
                    title: String(c.title || "")
                };
            }
            const keys = Object.keys(map).sort();
            let sig = "";
            for (let k = 0; k < keys.length; k++) {
                const e = map[keys[k]];
                sig += keys[k] + ":" + e.x + "," + e.y + "," + e.w + "," + e.h + "," + e.floating + "," + e.workspace + "," + e.fullscreen + ";";
            }
            if (sig === layoutSig)
                return;
            layoutSig = sig;
            layoutByAddr = map;
            layoutEpoch++;
        } catch (e) {
            console.log("Globals: clients json parse failed", e);
        }
    }

    // Tiled columns left→right, then top→bottom in a column; floaters after.
    function layoutKey(t) {
        const addr = normAddr(t?.address || t?.lastIpcObject?.address);
        const hit = addr ? layoutByAddr[addr] : null;
        if (hit)
            return { x: hit.x, y: hit.y, floating: hit.floating ? 1 : 0 };
        const at = t?.lastIpcObject?.at;
        if (Array.isArray(at) && at.length >= 1)
            return { x: Number(at[0]) || 0, y: Number(at[1]) || 0, floating: t?.lastIpcObject?.floating ? 1 : 0 };
        return { x: 0, y: 0, floating: 0 };
    }

    function cmpLayout(a, b) {
        const pa = layoutKey(a);
        const pb = layoutKey(b);
        if (pa.floating !== pb.floating)
            return pa.floating - pb.floating;
        if (pa.x !== pb.x)
            return pa.x - pb.x;
        if (pa.y !== pb.y)
            return pa.y - pb.y;
        return 0;
    }

    // Never restart mid-flight: aborting the collector yields truncated JSON.
    function refreshLayoutOrder() {
        if (clientsProc.running)
            return;
        clientsProc.running = true;
    }

    // ── Palette-aware icon resolution ───────────────────────────────────────
    // Tray items advertise `image://icon/<name>`, which Qt resolves through the
    // system icon theme (dark here) — monochrome glyphs then disappear on the
    // light palette. Resolve those names inside the palette's own theme instead.
    readonly property string iconResolveScript: Quickshell.shellPath("scripts/resolve-icons.py")
    // "<theme>|<mode>|<name>" -> absolute path, "" when the theme has no such icon
    property var themeIcons: ({})
    property var iconQueue: []
    property string iconQueueTheme: ""
    property string iconBatchKey: ""
    property var iconBatchNames: []

    function iconNameFromUrl(url) {
        const s = String(url || "");
        const prefix = "image://icon/";
        if (s.indexOf(prefix) !== 0)
            return "";
        let rest = s.slice(prefix.length);
        const q = rest.indexOf("?");
        if (q >= 0)
            rest = rest.slice(0, q);
        try {
            return decodeURIComponent(rest);
        } catch (e) {
            return rest;
        }
    }

    // "" while a lookup is in flight and when the theme has no such icon
    function themedIcon(name, theme, mode) {
        if (!name || !theme)
            return "";
        const hit = themeIcons[theme + "|" + mode + "|" + name];
        if (hit === undefined) {
            queueIconResolve(name, theme, mode);
            return "";
        }
        return hit ? "file://" + hit : "";
    }

    // True once a lookup finished (hit or confirmed miss). Pending names
    // must not fall through to a cached generic like "steam".
    function iconReady(name, theme, mode) {
        if (!name || !theme)
            return true;
        return themeIcons[theme + "|" + mode + "|" + name] !== undefined;
    }

    function openCtxMenu(items, x, y) {
        ctxMenuItems = items || [];
        ctxMenuX = x;
        ctxMenuY = y;
        ctxMenuOpen = true;
    }

    // Only icon *names* can be re-themed. Apps that publish a fixed pixmap keep
    // it — the tray id is no help there, since every Chromium app reports
    // "chrome_status_icon_1" — so TrayIcon re-inks those instead.
    function trayIconSource(url, theme) {
        const name = iconNameFromUrl(url);
        if (!name)
            return url;
        return themedIcon(name, theme, "mono") || url;
    }

    function queueIconResolve(name, theme, mode) {
        iconQueueTheme = theme;
        for (let i = 0; i < iconQueue.length; i++) {
            if (iconQueue[i].name === name && iconQueue[i].mode === mode)
                return;
        }
        iconQueue.push({ name: name, mode: mode });
        iconResolveTimer.restart();
    }

    function runIconResolve() {
        const theme = iconQueueTheme;
        if (iconProc.running || !iconQueue.length || !theme) {
            if (iconQueue.length)
                iconResolveTimer.restart();
            return;
        }
        // One process per mode; whatever is left goes in the next batch
        const mode = iconQueue[0].mode;
        const names = [];
        const rest = [];
        for (let i = 0; i < iconQueue.length; i++) {
            if (iconQueue[i].mode === mode)
                names.push(iconQueue[i].name);
            else
                rest.push(iconQueue[i]);
        }
        iconQueue = rest;
        if (rest.length)
            iconResolveTimer.restart();
        iconBatchKey = theme + "|" + mode;
        iconBatchNames = names;
        iconProc.command = ["python3", iconResolveScript, theme, mode].concat(names);
        iconProc.running = true;
    }

    function ingestIconJson(text) {
        const key = iconBatchKey;
        const names = iconBatchNames;
        if (!key || !names.length)
            return;
        let found = {};
        try {
            const parsed = JSON.parse(String(text || "").trim());
            if (parsed && typeof parsed === "object")
                found = parsed;
        } catch (e) {
            console.log("Globals: icon resolve parse failed", e);
        }
        const merged = {};
        const keys = Object.keys(themeIcons);
        for (let i = 0; i < keys.length; i++)
            merged[keys[i]] = themeIcons[keys[i]];
        // Cache misses too, otherwise the binding re-queues forever
        for (let j = 0; j < names.length; j++)
            merged[key + "|" + names[j]] = String(found[names[j]] || "");
        themeIcons = merged;
    }

    function glassColor(alpha) {
        // Mainframe: raised panel wash (not dark glass)
        return Qt.rgba(0.95, 0.96, 0.97, alpha)
    }

    function applyTintJson(text) {
        try {
            const j = JSON.parse(String(text || "").trim());
            if (typeof j.r === "number")
                wallR = Math.max(0, Math.min(1, j.r));
            if (typeof j.g === "number")
                wallG = Math.max(0, Math.min(1, j.g));
            if (typeof j.b === "number")
                wallB = Math.max(0, Math.min(1, j.b));
            if (j.path)
                wallPath = String(j.path);
        } catch (e) {
            // keep previous tint
        }
    }

    function refreshWallpaperTint() {
        tintProc.running = false;
        tintProc.running = true;
    }

    function applySysStats(text) {
        try {
            const j = JSON.parse(String(text || "").trim());
            const cpu = parseInt(j.cpu, 10);
            const ram = parseInt(j.ram, 10);
            if (!isNaN(cpu))
                cpuPct = Math.max(0, Math.min(100, cpu));
            if (!isNaN(ram))
                ramPct = Math.max(0, Math.min(100, ram));
            if (j.rx !== undefined)
                netRx = String(j.rx);
            if (j.tx !== undefined)
                netTx = String(j.tx);
        } catch (e) {
        }
    }

    function refreshSysStats() {
        sysStatsProc.running = false;
        sysStatsProc.running = true;
    }

    Process {
        id: sysStatsProc
        command: ["python3", Globals.sysStatsScript]
        stdout: StdioCollector {
            id: sysStatsOut
            waitForEnd: true
            onStreamFinished: Globals.applySysStats(sysStatsOut.text)
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Globals.refreshSysStats()
    }

    Process {
        id: tintProc
        command: ["python3", Globals.wallpaperTintScript]
        stdout: StdioCollector {
            id: tintOut
            waitForEnd: true
            onStreamFinished: Globals.applyTintJson(tintOut.text)
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    // Cache for instant first paint before ffmpeg finishes
    FileView {
        id: tintCache
        path: `${Quickshell.env("HOME")}/.cache/qs-wallpaper-tint.json`
        blockLoading: true
        watchChanges: true
        onLoaded: Globals.applyTintJson(text())
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    Timer {
        interval: 45000
        running: true
        repeat: true
        onTriggered: Globals.refreshWallpaperTint()
    }

    Component.onCompleted: Qt.callLater(() => {
        Globals.refreshWallpaperTint();
        Globals.refreshLayoutOrder();
    })

    // Refresh when an overlay opens (picks up wallpaper changes quickly)
    onLauncherOpenChanged: if (launcherOpen)
        refreshWallpaperTint()
    onEmojiOpenChanged: if (emojiOpen)
        refreshWallpaperTint()
    onNotifDrawerOpenChanged: if (notifDrawerOpen)
        refreshWallpaperTint()

    function closeOverlays() {
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        startMenuOpen = false;
        launcherOpen = false;
        emojiOpen = false;
    }

    function toggleMixer() {
        mixerOpen = !mixerOpen;
        if (mixerOpen) {
            notifDrawerOpen = false;
            powerMenuOpen = false;
            startMenuOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function openMixer() {
        mixerOpen = true;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        startMenuOpen = false;
        launcherOpen = false;
        emojiOpen = false;
    }

    function closeMixer() {
        mixerOpen = false;
    }

    function toggleNotifs() {
        notifDrawerOpen = !notifDrawerOpen;
        if (notifDrawerOpen) {
            mixerOpen = false;
            powerMenuOpen = false;
            startMenuOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function toggleStart() {
        startMenuOpen = !startMenuOpen;
        if (startMenuOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            powerMenuOpen = false;
            launcherOpen = false;
            emojiOpen = false;
        }
    }

    function togglePower() {
        toggleStart();
    }

    function formatAddress(addr) {
        if (addr === undefined || addr === null || addr === "")
            return "";
        let s = String(addr).trim();
        if (s.indexOf("0x") === 0 || s.indexOf("0X") === 0)
            return s;
        if (/^[0-9]+$/.test(s))
            return "0x" + Number(s).toString(16);
        if (/^[0-9a-fA-F]+$/.test(s))
            return "0x" + s;
        return s;
    }

    // Capture the real client under focus BEFORE an overlay steals it
    function captureInsertTarget() {
        const t = Hyprland.activeToplevel || Hyprland.focusedToplevel;
        insertTargetAddress = formatAddress(t?.address || t?.lastIpcObject?.address);
    }

    function toggleLauncher() {
        if (!launcherOpen)
            captureInsertTarget();
        launcherOpen = !launcherOpen;
        if (launcherOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            powerMenuOpen = false;
            startMenuOpen = false;
            emojiOpen = false;
        }
    }

    function openLauncher() {
        captureInsertTarget();
        launcherOpen = true;
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        startMenuOpen = false;
        emojiOpen = false;
    }

    function closeLauncher() {
        launcherOpen = false;
    }

    function toggleEmoji() {
        if (!emojiOpen)
            captureInsertTarget();
        emojiOpen = !emojiOpen;
        if (emojiOpen) {
            mixerOpen = false;
            notifDrawerOpen = false;
            powerMenuOpen = false;
            startMenuOpen = false;
            launcherOpen = false;
        }
    }

    function openEmoji() {
        captureInsertTarget();
        emojiOpen = true;
        mixerOpen = false;
        notifDrawerOpen = false;
        powerMenuOpen = false;
        startMenuOpen = false;
        launcherOpen = false;
    }

    function closeEmoji() {
        emojiOpen = false;
    }

    // Steam hover cards / right-click menus show up as extra Hyprland
    // toplevels (usually class steam/steamwebhelper, title "Steam" or
    // empty, floating, small). They must not become tabs or pill icons.
    function isBarToplevel(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;

        const cls = String(ipc.class || ipc.initialClass || t.classname || "").toLowerCase();
        if (!cls || cls.indexOf("quickshell") >= 0)
            return false;

        const title = String(ipc.title || t.title || "").trim();
        const tag = String(ipc.xdgTag || ipc.xdgDescription || "").toLowerCase();
        if (/menu|popup|tooltip|dropdown|combo/.test(tag))
            return false;

        const sz = ipc.size;
        let w = 0, h = 0;
        if (Array.isArray(sz) && sz.length >= 2) {
            w = Number(sz[0]) || 0;
            h = Number(sz[1]) || 0;
        } else if (sz && typeof sz === "object") {
            w = Number(sz.w ?? sz.x ?? sz[0]) || 0;
            h = Number(sz.h ?? sz.y ?? sz[1]) || 0;
        }
        const area = w * h;
        const floating = !!ipc.floating;
        const steamChrome = cls === "steam" || cls === "steamwebhelper"
            || cls === "steamwebhelperproxy" || cls.indexOf("gameoverlay") >= 0;

        if (/notificationtoasts|gameoverlayui/i.test(title) || cls.indexOf("gameoverlay") >= 0)
            return false;

        if (steamChrome) {
            if (!title)
                return false;
            // Menus reuse the parent title ("Steam") and stay small + floating.
            // Size can be 0 in stale IPC — still drop those, not a real client.
            if (floating && (area <= 0 || area < 500 * 400 || w < 280 || h < 160))
                return false;
        }

        if (floating && !title && area > 0 && area < 360 * 280)
            return false;

        return true;
    }

    function workspaceIdOf(t) {
        const ipc = t?.lastIpcObject || {};
        const ws = ipc.workspace ?? t?.workspace;
        if (ws === undefined || ws === null)
            return -1;
        if (typeof ws === "number")
            return Number(ws);
        if (typeof ws === "object") {
            if (ws.id !== undefined && ws.id !== null)
                return Number(ws.id);
            if (ws.name !== undefined) {
                const n = Number(String(ws.name).replace(/[^0-9-]/g, ""));
                if (n > 0)
                    return n;
            }
        }
        const n = Number(ws);
        return n > 0 ? n : -1;
    }

    function occupiedWorkspaceIds() {
        void toplevelEpoch;
        void layoutEpoch;
        const focused = Number(Hyprland.focusedWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1);
        const ids = {};
        const list = Hyprland.workspaces?.values || [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            const id = Number(ws.id);
            if (!(id > 0))
                continue;
            let n = Number(ws.lastIpcObject?.windows) || 0;
            if (n <= 0) {
                const nested = ws.toplevels;
                if (nested?.values)
                    n = nested.values.length;
                else if (nested?.length !== undefined)
                    n = nested.length;
            }
            if (n > 0)
                ids[id] = true;
        }
        const tops = Hyprland.toplevels?.values || [];
        for (let i = 0; i < tops.length; i++) {
            if (!isBarToplevel(tops[i]))
                continue;
            const wid = workspaceIdOf(tops[i]);
            if (wid > 0)
                ids[wid] = true;
        }
        if (focused > 0)
            ids[focused] = true;
        const sorted = Object.keys(ids).map(k => Number(k)).sort((a, b) => a - b);
        return sorted.length ? sorted : [focused > 0 ? focused : 1];
    }

    function switchWorkspace(id) {
        dispatchKeepCursor("workspace " + id);
    }

    function cycleWorkspace(delta) {
        const ids = occupiedWorkspaceIds();
        if (!ids.length)
            return;
        const cur = Number(Hyprland.focusedWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1);
        let idx = 0;
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === cur) {
                idx = i;
                break;
            }
        }
        switchWorkspace(ids[(idx + delta + ids.length * 8) % ids.length]);
    }

    // Hyprland warps the pointer into the focused window on workspace/window
    // change. Bar scroll/click must leave the cursor where it is.
    function dispatchKeepCursor(hyprArgs) {
        const safe = String(hyprArgs || "").replace(/'/g, "");
        if (!safe)
            return;
        if (cursorPin.running)
            cursorPin.running = false;
        cursorPin.command = ["sh", "-c",
            'pos=$(hyprctl cursorpos); ' +
            'x=${pos%%,*}; y=${pos#*,}; y=${y// /}; ' +
            'hyprctl dispatch ' + safe + '; ' +
            'sleep 0.03; hyprctl dispatch movecursor "$x" "$y"; ' +
            'sleep 0.05; hyprctl dispatch movecursor "$x" "$y"'
        ];
        cursorPin.running = true;
    }

    Process { id: cursorPin }

    Timer {
        id: iconResolveTimer
        interval: 90
        onTriggered: Globals.runIconResolve()
    }

    Process {
        id: iconProc
        stdout: StdioCollector {
            id: iconOut
            waitForEnd: true
            onStreamFinished: Globals.ingestIconJson(iconOut.text)
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsOut
            waitForEnd: true
            onStreamFinished: Globals.ingestClientsJson(clientsOut.text)
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event?.name || "";
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspace", "focusedmon", "activewindow", "activewindowv2", "windowtitlev2"].indexOf(name) >= 0)
                Globals.refreshLayoutOrder();
        }
    }

    // swapcol / scroll-camera often moves `at` without a dedicated event
    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: Globals.refreshLayoutOrder()
    }
}

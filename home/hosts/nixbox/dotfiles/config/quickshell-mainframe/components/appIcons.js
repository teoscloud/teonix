.pragma library

var aliases = {
    "cursor": ["code-cursor", "cursor", "Cursor"],
    "code-cursor": ["cursor", "code-cursor"],
    "brave-browser": ["brave-browser", "brave", "brave-desktop"],
    "brave": ["brave-browser", "brave"],
    "google-chrome": ["google-chrome", "chrome", "google-chrome-stable"],
    "google-chrome-stable": ["google-chrome", "chrome"],
    "chrome": ["google-chrome", "chrome"],
    "chromium": ["chromium", "chromium-browser"],
    "firefox": ["firefox", "org.mozilla.firefox"],
    "signal": ["signal", "signal-desktop"],
    "codium": ["vscodium", "codium", "com.vscodium.codium"],
    "vscodium": ["codium", "vscodium", "com.vscodium.codium"],
    "equibop": ["equibop", "discord"],
    "discord": ["discord", "discord-canary", "equibop"],
    "slack": ["slack"],
    "spotify": ["spotify-client", "spotify", "com.spotify.Client"],
    "steam": ["steam", "steam-native"],
    "buschain-control": ["multimedia-volume-control", "audio-card", "audio-volume-high"],
    "thehouse-trading": ["thehouse-trading"],
    "code": ["code", "vscode", "visual-studio-code"],
    "kitty": ["kitty"],
    "org.kde.dolphin": ["dolphin"],
    "thunar": ["org.xfce.thunar", "thunar"]
}

function normalizeKey(v) {
    let s = String(v || "").toLowerCase().trim()
    if (s.endsWith(".desktop"))
        s = s.slice(0, -8)
    return s.replace(/\s+/g, "").replace(/_/g, "-")
}

function addName(names, v) {
    const s = String(v || "").trim()
    if (!s)
        return
    if (names.indexOf(s) < 0)
        names.push(s)
    const low = s.toLowerCase()
    if (names.indexOf(low) < 0)
        names.push(low)
    const key = normalizeKey(s)
    if (key && names.indexOf(key) < 0)
        names.push(key)
}

function steamAppId(clsOrApp) {
    let raw = ""
    if (typeof clsOrApp === "object" && clsOrApp)
        raw = String(clsOrApp.className || clsOrApp.desktopId || clsOrApp.id || clsOrApp.iconName || "")
    else
        raw = String(clsOrApp || "")
    const m = raw.match(/steam[-_]?app[-_]?(\d+)/i) || raw.match(/steam[-_]?icon[-_]?(\d+)/i)
    return m ? m[1] : ""
}

function candidates(clsOrApp) {
    const names = []
    let raw = ""
    if (typeof clsOrApp === "object" && clsOrApp) {
        addName(names, clsOrApp.iconName)
        addName(names, clsOrApp.className)
        addName(names, clsOrApp.desktopId)
        addName(names, clsOrApp.id)
        raw = String(clsOrApp.className || clsOrApp.desktopId || clsOrApp.iconName || "")
    } else {
        raw = String(clsOrApp || "")
        addName(names, raw)
    }
    const stem = raw.split(".").pop() || raw
    addName(names, stem)
    const parts = raw.split(".")
    if (parts.length >= 2)
        addName(names, parts.slice(-2).join("."))
    const key = normalizeKey(raw)
    const appid = steamAppId(clsOrApp)
    if (appid) {
        addName(names, "steam_app_" + appid)
        addName(names, "steam-app-" + appid)
        addName(names, "steam_icon_" + appid)
        addName(names, "steam-icon-" + appid)
    }
    const als = aliases[key] || aliases[normalizeKey(stem)]
    if (als) {
        for (let i = 0; i < als.length; i++) {
            if (appid && normalizeKey(als[i]) === "steam")
                continue
            addName(names, als[i])
        }
    }
    return names
}

function resolve(iconPathFn, clsOrApp, isReadyFn) {
    if (typeof clsOrApp === "object" && clsOrApp) {
        const path = clsOrApp.iconPath || ""
        if (path && path.charAt(0) === "/")
            return "file://" + path
    }
    const list = candidates(clsOrApp)
    let pending = false
    for (let i = 0; i < list.length; i++) {
        if (typeof isReadyFn === "function" && !isReadyFn(list[i])) {
            try { iconPathFn(list[i]) } catch (e) {}
            pending = true
            continue
        }
        try {
            const p = iconPathFn(list[i])
            if (p)
                return p
        } catch (e) {
        }
    }
    if (pending)
        return ""
    if (steamAppId(clsOrApp)) {
        try {
            const p = iconPathFn("steam")
            if (p)
                return p
        } catch (e) {
        }
    }
    return ""
}

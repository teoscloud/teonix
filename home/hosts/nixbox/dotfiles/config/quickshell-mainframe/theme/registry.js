.pragma library

var palettes = [
    { id: "light", label: "White Mainframe", short: "White", file: "tokens-light.js" },
    { id: "dark", label: "Charcoal Mainframe", short: "Charcoal", file: "tokens-dark.js" }
]

function ids() {
    return palettes.map(function (p) { return p.id; })
}

function find(id) {
    for (var i = 0; i < palettes.length; i++) {
        if (palettes[i].id === id)
            return palettes[i]
    }
    return palettes[0]
}

function nextId(current) {
    var list = ids()
    var idx = list.indexOf(current)
    if (idx < 0)
        return list[0]
    return list[(idx + 1) % list.length]
}

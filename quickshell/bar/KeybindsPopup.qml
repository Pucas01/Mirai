import QtQuick
import Quickshell
import Quickshell.Io

Window {
    id: keybindsWin
    property var binds: []

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-keybinds"
    color: "transparent"
    width: 980
    height: 780
    visible: false

    function toggle() {
        if (keybindsWin.visible) close()
        else open()
    }

    function open() {
        visible = true
        raise()
        requestActivate()
        refresh()
    }

    function close() {
        visible = false
    }

    function refresh() {
        bindsProc.running = false
        bindsProc.running = true
    }

    function modString(modmask) {
        var parts = []
        if (modmask & 64) parts.push("SUPER")
        if (modmask & 8) parts.push("ALT")
        if (modmask & 4) parts.push("CTRL")
        if (modmask & 1) parts.push("SHIFT")
        return parts
    }

    function keyLabel(entry) {
        if (entry.mouse) {
            var m = entry.key.match(/(\d+)$/)
            if (entry.key === "mouse_down") return "Scroll Down"
            if (entry.key === "mouse_up") return "Scroll Up"
            if (m) return "Mouse " + m[1]
            return entry.key
        }
        if (entry.key.startsWith("XF86")) return entry.key.replace("XF86", "")
        if (entry.key === "left") return "←"
        if (entry.key === "right") return "→"
        if (entry.key === "up") return "↑"
        if (entry.key === "down") return "↓"
        return entry.key.toUpperCase()
    }

    function groupBinds(entries) {
        var groups = {}
        var order = []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            var m = e.description.match(/^(.*\D)\s*(\d+)$/)
            var base = m ? m[1].trim() : e.description
            var num = m ? m[2] : null
            var groupKey = e.combo.replace(/\d+$/, "") + "|" + base

            if (!groups[groupKey]) {
                groups[groupKey] = { modsPrefix: e.combo.replace(/\d+$/, ""), base: base, nums: [], plainCombo: e.combo, description: e.description }
                order.push(groupKey)
            }
            if (num !== null) groups[groupKey].nums.push(num)
        }

        var out = []
        for (var j = 0; j < order.length; j++) {
            var g = groups[order[j]]
            if (g.nums.length >= 3) {
                out.push({ combo: g.modsPrefix + "1-0", description: g.base })
            } else {
                out.push({ combo: g.plainCombo, description: g.description })
            }
        }
        return out
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    var raw = []
                    for (var i = 0; i < parsed.length; i++) {
                        var b = parsed[i]
                        if (!b.description || b.description === "") continue
                        var mods = keybindsWin.modString(b.modmask)
                        var keyStr = keybindsWin.keyLabel(b)
                        var combo = mods.concat([keyStr]).join(" + ")
                        raw.push({ combo: combo, description: b.description })
                    }
                    keybindsWin.binds = keybindsWin.groupBinds(raw)
                } catch (e) {
                    keybindsWin.binds = []
                }
            }
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void { keybindsWin.toggle() }
        function show(): void { keybindsWin.open() }
        function hide(): void { keybindsWin.close() }
    }

    Rectangle {
        id: keybindsRect
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#39c5bb"
        border.width: 1

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 36

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: "keybinds"
                    color: "#999999"
                    font.pixelSize: 11; font.family: "monospace"
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    text: keybindsWin.binds.length + " binds"
                    color: "#555555"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: "#2a2a2a"
                }
            }

            GridView {
                id: bindsGrid
                width: parent.width
                height: parent.height - 36
                clip: true
                cellWidth: width / 2
                cellHeight: 44
                model: keybindsWin.binds

                delegate: Item {
                    id: bindDelegate
                    required property var modelData
                    width: bindsGrid.cellWidth
                    height: bindsGrid.cellHeight

                    Column {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: parent.right; rightMargin: 16 }
                        spacing: 2

                        Text {
                            text: bindDelegate.modelData.combo
                            color: "#39c5bb"
                            font.pixelSize: 13; font.family: "monospace"; font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Text {
                            text: bindDelegate.modelData.description
                            color: "#bbbbbb"
                            font.pixelSize: 11; font.family: "monospace"
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}

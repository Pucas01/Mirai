import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

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

    component SectionBanner: Item {
        property string label: ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        height: 26

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cut = 14, w = width, h = height
                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - cut)
                ctx.lineTo(w - cut, h); ctx.lineTo(0, h); ctx.closePath()
                var base = ctx.createLinearGradient(0, 0, 0, h)
                base.addColorStop(0, "#5a5a5a"); base.addColorStop(0.08, "#454545")
                base.addColorStop(0.5, "#3a3a3a"); base.addColorStop(1.0, "#2e2e2e")
                ctx.fillStyle = base
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5); ctx.lineTo(0, h * 0.5); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                gloss.addColorStop(0, "rgba(255,255,255,0.18)")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss
                ctx.fill()
            }
        }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
            text: parent.label.toUpperCase()
            color: "#ffffff"
            font.pixelSize: 11; font.family: "Orbitron"; font.bold: true
            font.letterSpacing: 2
        }

        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
            text: keybindsWin.binds.length + " binds"
            color: "#c8f4f0"
            font.pixelSize: 10; font.family: "monospace"
        }
    }

    PanelBackground {
        id: keybindsRect
        anchors.fill: parent

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item { width: 1; height: 12 }

            SectionBanner { label: "keybinds" }

            Item { width: 1; height: 10 }

            GridView {
                id: bindsGrid
                width: parent.width
                height: parent.height - 48
                clip: true
                cellWidth: width / 2
                cellHeight: 54
                model: keybindsWin.binds

                delegate: Item {
                    id: bindDelegate
                    required property var modelData
                    width: bindsGrid.cellWidth
                    height: bindsGrid.cellHeight

                    Item {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 6; topMargin: 4; bottomMargin: 4 }

                        Canvas {
                            id: rowCanvas
                            anchors.fill: parent
                            onPaint: DivaPaint.paintFacetPill(rowCanvas, 0.0, 6)
                        }

                        Column {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14; right: parent.right; rightMargin: 14 }
                            spacing: 6

                            Row {
                                spacing: 5

                                Repeater {
                                    model: bindDelegate.modelData.combo.split(" + ")

                                    delegate: Item {
                                        id: keyChip
                                        required property string modelData
                                        height: 21
                                        width: keyChipText.width + 14

                                        Canvas {
                                            anchors.fill: parent
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                var w = width, h = height, cut = 5
                                                ctx.clearRect(0, 0, w, h)

                                                function drawShape() {
                                                    ctx.beginPath()
                                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                                    ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                                    ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                                                }

                                                drawShape()
                                                var base = ctx.createLinearGradient(0, 0, 0, h)
                                                base.addColorStop(0, "#28302f"); base.addColorStop(0.5, "#1c2322"); base.addColorStop(1.0, "#161c1b")
                                                ctx.fillStyle = base; ctx.fill()

                                                ctx.beginPath()
                                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.55)
                                                ctx.lineTo(0, h * 0.55); ctx.lineTo(0, cut); ctx.closePath()
                                                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                                                gloss.addColorStop(0, "rgba(150,245,245,0.12)")
                                                gloss.addColorStop(1, "rgba(150,245,245,0.00)")
                                                ctx.fillStyle = gloss; ctx.fill()

                                                drawShape()
                                                ctx.strokeStyle = "#3f7570"
                                                ctx.lineWidth = 1
                                                ctx.stroke()
                                            }
                                        }

                                        Text {
                                            id: keyChipText
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            color: "#a8f0ec"
                                            font.pixelSize: 10; font.family: "monospace"; font.bold: true
                                            font.letterSpacing: 0.4
                                        }
                                    }
                                }
                            }

                            Text {
                                text: bindDelegate.modelData.description
                                color: "#b0b0b0"
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
}

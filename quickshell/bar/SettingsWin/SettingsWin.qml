import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Window {
    id: settingsWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-settings"
    color: "transparent"
    width: 920
    height: 640
    visible: false

    property alias audioSliderActive: audioSectionInstance.sliderActive

    readonly property string homeDir: Quickshell.env("HOME")

    property string section: "wallpaper"
    property string wallpaperDir: settingsWin.homeDir + "/Pictures/Mirai/Wallpapers"
    property string appliedWallpaper: ""

    property string pfpDir: settingsWin.homeDir + "/Pictures/Mirai/Avatars"
    property string pfpStatePath: settingsWin.homeDir + "/.cache/qs-pfp-path"
    property string pfpPath: ""

    function setPfp(path) {
        settingsWin.pfpPath = path
        savePfpProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + settingsWin.pfpStatePath + "\" <<'PFP_EOF'\n" + path + "\nPFP_EOF\n"]
        savePfpProc.running = false
        savePfpProc.running = true
    }

    readonly property string defaultStartIcon: "󰣇"
    property string startIconDir: settingsWin.homeDir + "/Pictures/Mirai/StartIcon"
    property string startIconStatePath: settingsWin.homeDir + "/.cache/qs-start-icon-path"
    property string startIconPath: ""

    function setStartIconImage(path) {
        settingsWin.startIconPath = path
        saveStartIconProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + settingsWin.startIconStatePath + "\" <<'ICON_EOF'\n" + path + "\nICON_EOF\n"]
        saveStartIconProc.running = false
        saveStartIconProc.running = true
    }

    property string cursorTheme: "default"
    property int cursorSize: 24
    readonly property string cursorAppliedTheme: cursorTheme
    property bool cursorApplied: false
    property string cursorError: ""

    function applyCursor(theme, size) {
        settingsWin.cursorTheme = theme
        settingsWin.cursorSize = size
        applyCursorProc.command = ["hyprctl", "setcursor", theme, String(size)]
        applyCursorProc.running = false
        applyCursorProc.running = true
        writeCursorEnvProc.command = ["bash", settingsWin.homeDir + "/.config/hypr/scripts/set-cursor.sh", theme, String(size)]
        writeCursorEnvProc.running = false
        writeCursorEnvProc.running = true
        saveCursorStateProc.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s\\n%s\\n' \"" + theme + "\" \"" + size + "\" > \"" + settingsWin.cursorStatePath + "\""]
        saveCursorStateProc.running = false
        saveCursorStateProc.running = true
    }

    property string cursorStatePath: settingsWin.homeDir + "/.cache/qs-cursor-state"
    property string cursorThemesDir: "/usr/share/icons"
    property string cursorPreviewsDir: settingsWin.homeDir + "/.cache/mirai-cursor-previews"

    property string monitorsLuaPath: settingsWin.homeDir + "/.config/hypr/monitors.lua"
    property var monitors: []
    property bool monitorsRefreshed: false
    property bool monitorsApplied: false
    property bool monitorsSaved: false
    property string monitorsError: ""
    property string selectedMonitorName: ""
    property var selectedMonitor: settingsWin.monitors.find(function(m) { return m.name === settingsWin.selectedMonitorName }) || null

    function setMonitorMode(name, width, height, refreshRate) {
        var arr = settingsWin.monitors.map(function(m) {
            var c = {}
            for (var k in m) c[k] = m[k]
            return c
        })
        var mon = arr.find(function(m) { return m.name === name })
        if (!mon) return
        mon.width = width
        mon.height = height
        mon.refreshRate = refreshRate
        settingsWin.monitors = arr
    }

    function setMonitorScale(name, scale) {
        var arr = settingsWin.monitors.map(function(m) {
            var c = {}
            for (var k in m) c[k] = m[k]
            return c
        })
        var mon = arr.find(function(m) { return m.name === name })
        if (!mon) return
        mon.scale = Math.max(0.5, Math.min(3.0, scale))
        settingsWin.monitors = arr
    }

    function refreshMonitors() {
        monitorsProc.running = false
        monitorsProc.running = true
    }

    function applyMonitors() {
        var parts = settingsWin.monitors.map(function(m) {
            var res = m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2)
            var pos = Math.round(m.x) + "x" + Math.round(m.y)
            return 'hl.monitor({ output = "' + m.name + '", mode = "' + res + '", position = "' + pos + '", scale = ' + m.scale.toFixed(2) + " })"
        })
        if (parts.length === 0) return
        applyMonitorsProc.command = ["hyprctl", "eval", parts.join("; ")]
        applyMonitorsProc.running = false
        applyMonitorsProc.running = true
    }

    function buildMonitorsLua() {
        var lines = ["-- Managed by qs-settings (monitors page). Edits here may be overwritten.", ""]
        for (var i = 0; i < settingsWin.monitors.length; i++) {
            var m = settingsWin.monitors[i]
            var res = m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2)
            var pos = Math.round(m.x) + "x" + Math.round(m.y)
            lines.push('hl.monitor({ output = "' + m.name + '", mode = "' + res + '", position = "' + pos + '", scale = ' + m.scale.toFixed(2) + " })")
        }
        return lines.join("\n") + "\n"
    }

    function saveMonitors() {
        writeMonitorsProc.command = ["bash", "-c", "cat > \"" + settingsWin.monitorsLuaPath + "\" <<'MONITORS_LUA_EOF'\n" + settingsWin.buildMonitorsLua() + "\nMONITORS_LUA_EOF\n"]
        writeMonitorsProc.running = false
        writeMonitorsProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            floatProc.running = false; floatProc.running = true
            wallpaperSectionInstance.ensureDir()
            customizationSectionInstance.ensureDir()
            ensurePfpDirProc.running = false; ensurePfpDirProc.running = true
            ensureStartIconDirProc.running = false; ensureStartIconDirProc.running = true
            genCursorPreviewsProc.running = false; genCursorPreviewsProc.running = true
            if (settingsWin.section === "monitors") settingsWin.refreshMonitors()
        }
    }

    onSectionChanged: if (section === "monitors") refreshMonitors()

    Component.onCompleted: { loadPfpProc.running = true; loadStartIconProc.running = true; loadCursorProc.running = true }

    Process {
        id: floatProc
        command: ["hyprctl", "dispatch", "setfloating", "title:qs-settings"]
    }

    Process {
        id: ensurePfpDirProc
        command: ["mkdir", "-p", settingsWin.pfpDir]
        running: false
        onExited: customizationSectionInstance.refreshPfpModel()
    }

    Process {
        id: openPfpDirProc
        command: ["nautilus", settingsWin.pfpDir]
        running: false
    }

    Process {
        id: loadPfpProc
        command: ["cat", settingsWin.pfpStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { settingsWin.pfpPath = text.trim() }
        }
    }

    Process {
        id: savePfpProc
        command: ["true"]
        running: false
    }

    Process {
        id: loadStartIconProc
        command: ["cat", settingsWin.startIconStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { settingsWin.startIconPath = text.trim() }
        }
    }

    Process {
        id: saveStartIconProc
        command: ["true"]
        running: false
    }

    Process {
        id: ensureStartIconDirProc
        command: ["mkdir", "-p", settingsWin.startIconDir]
        running: false
        onExited: customizationSectionInstance.refreshStartIconModel()
    }

    Process {
        id: openStartIconDirProc
        command: ["nautilus", settingsWin.startIconDir]
        running: false
    }

    Process {
        id: loadCursorProc
        command: ["cat", settingsWin.cursorStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length >= 1 && lines[0].length > 0) settingsWin.cursorTheme = lines[0].trim()
                if (lines.length >= 2) {
                    var n = parseInt(lines[1].trim(), 10)
                    if (!isNaN(n) && n > 0) settingsWin.cursorSize = n
                }
            }
        }
    }

    Process {
        id: applyCursorProc
        command: ["true"]
        running: false
        onExited: code => {
            if (code === 0) {
                settingsWin.cursorApplied = true
                cursorAppliedTimer.start()
            } else {
                settingsWin.cursorError = "apply failed (exit " + code + ")"
                cursorErrorTimer.start()
            }
        }
    }

    Process {
        id: writeCursorEnvProc
        command: ["true"]
        running: false
        onExited: code => {
            if (code !== 0) {
                settingsWin.cursorError = "save failed (exit " + code + ")"
                cursorErrorTimer.start()
            }
        }
    }

    Process {
        id: saveCursorStateProc
        command: ["true"]
        running: false
    }

    Timer { id: cursorAppliedTimer; interval: 1200; onTriggered: settingsWin.cursorApplied = false }
    Timer { id: cursorErrorTimer; interval: 4000; onTriggered: settingsWin.cursorError = "" }

    Process {
        id: genCursorPreviewsProc
        command: ["bash", settingsWin.homeDir + "/.config/hypr/scripts/gen-cursor-previews.sh"]
        running: false
        onExited: customizationSectionInstance.refreshCursorPreviews()
    }

    Process {
        id: openCursorThemesDirProc
        command: ["nautilus", settingsWin.cursorThemesDir]
        running: false
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    settingsWin.monitors = parsed.filter(function(m) { return m.width > 0 && m.height > 0 })
                    settingsWin.monitorsRefreshed = true
                    monitorsRefreshedTimer.start()
                } catch (e) {
                    settingsWin.monitorsError = "refresh failed: " + e
                    monitorsErrorTimer.start()
                }
            }
        }
    }

    Process {
        id: applyMonitorsProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "ok") {
                    settingsWin.monitorsApplied = true
                    monitorsAppliedTimer.start()
                } else {
                    settingsWin.monitorsError = "apply failed: " + text.trim()
                    monitorsErrorTimer.start()
                }
            }
        }
    }

    Process {
        id: writeMonitorsProc
        command: ["true"]
        running: false
        onExited: code => {
            if (code === 0) {
                settingsWin.monitorsSaved = true
                monitorsSavedTimer.start()
            } else {
                settingsWin.monitorsError = "save failed (exit " + code + ")"
                monitorsErrorTimer.start()
            }
        }
    }

    Timer { id: monitorsRefreshedTimer; interval: 1200; onTriggered: settingsWin.monitorsRefreshed = false }
    Timer { id: monitorsAppliedTimer; interval: 1200; onTriggered: settingsWin.monitorsApplied = false }
    Timer { id: monitorsSavedTimer; interval: 1200; onTriggered: settingsWin.monitorsSaved = false }
    Timer { id: monitorsErrorTimer; interval: 4000; onTriggered: settingsWin.monitorsError = "" }

    EthernetWin {
        id: ethernetWin
        connectionName: networkSectionInstance.ethernetName
        connected: networkSectionInstance.ethernetConnected
        onToggleFinished: networkSectionInstance.refreshActive()
    }

    PanelBackground {
        anchors.fill: parent

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "settings"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Item {
                id: closeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 28; height: 22

                Canvas {
                    id: closeBtnCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cut = 4, w = width, h = height, hp = closeBtnCanvas.hp
                        function drawShape() {
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                            ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                            ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                        }
                        drawShape()
                        var base = ctx.createLinearGradient(0, 0, 0, h)
                        base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
                        base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
                        ctx.fillStyle = base; ctx.fill()
                        if (hp > 0) {
                            drawShape()
                            var red = ctx.createLinearGradient(0, 0, 0, h)
                            red.addColorStop(0, "#f08080"); red.addColorStop(0.08, "#cc4444")
                            red.addColorStop(0.5, "#992e2e"); red.addColorStop(1.0, "#6a2a2a")
                            ctx.globalAlpha = hp; ctx.fillStyle = red; ctx.fill(); ctx.globalAlpha = 1.0
                        }
                        ctx.beginPath()
                        ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                        ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                        var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                        gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                        gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                        ctx.fillStyle = gloss; ctx.fill()
                        ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                        ctx.strokeStyle = hp > 0.5 ? "#ffc0c0" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.containsMouse ? "#ffffff" : "#999999"
                    font.pixelSize: 11
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: closeBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                    onClicked: settingsWin.visible = false
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2a2a2a"
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) settingsWin.startSystemMove()
            }
        }

        Row {
            anchors { top: titleBar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }

            Rectangle {
                width: 150
                height: parent.height
                color: "#161616"

                Column {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }

                    component NavItem: Item {
                        id: navItem
                        property string label: ""
                        property string sym: ""
                        property string target: ""
                        property bool active: settingsWin.section === target
                        width: parent.width
                        height: 38

                        Item {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 2; bottomMargin: 2 }

                            Canvas {
                                id: navCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: navItem
                                    function onActiveChanged() { navCanvas.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 6, w = width, h = height, ta = navItem.active ? 1.0 : navCanvas.hp
                                    function drawShape() {
                                        ctx.beginPath()
                                        ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                        ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                        ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                                    }
                                    drawShape()
                                    var base = ctx.createLinearGradient(0, 0, 0, h)
                                    base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
                                    base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
                                    ctx.fillStyle = base; ctx.fill()
                                    if (ta > 0) {
                                        drawShape()
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                        ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + ta * 0.2) + ")")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                spacing: 10
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.sym
                                    color: navItem.active || navArea.containsMouse ? "#ffffff" : "#888888"
                                    font.pixelSize: 14
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.label
                                    color: navItem.active || navArea.containsMouse ? "#ffffff" : "#999999"
                                    font.pixelSize: 11; font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: navCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: settingsWin.section = navItem.target
                            }
                        }
                    }

                    NavItem { sym: "󰸉"; label: "wallpaper"; target: "wallpaper" }
                    NavItem { sym: "󰍹"; label: "monitors"; target: "monitors" }
                    NavItem { sym: "󰕾"; label: "audio"; target: "audio" }
                    NavItem { sym: "󰂯"; label: "bluetooth"; target: "bluetooth" }
                    NavItem { sym: "󰤨"; label: "network"; target: "network" }
                    NavItem { sym: "󰆧"; label: "customization"; target: "customization" }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: 54 }
                    height: 1; color: "#2a2a2a"
                }

                NavItem {
                    anchors { bottom: parent.bottom; bottomMargin: 8 }
                    sym: "󰋽"
                    label: "about"
                    target: "about"
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height

                WallpaperSection {
                    id: wallpaperSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "wallpaper"
                }

                MonitorsSection {
                    id: monitorsSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "monitors"
                }

                AudioSection {
                    id: audioSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "audio"
                }

                BluetoothSection {
                    id: bluetoothSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "bluetooth"
                }

                NetworkSection {
                    id: networkSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "network"
                }

                CustomizationSection {
                    id: customizationSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "customization"
                }

                AboutSection {
                    id: aboutSectionInstance
                    settingsWin: settingsWin
                    sectionActive: settingsWin.section === "about"
                }
            }
        }
    }
}

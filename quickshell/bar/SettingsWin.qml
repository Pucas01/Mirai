import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Qt.labs.folderlistmodel

Window {
    id: settingsWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-settings"
    color: "transparent"
    width: 720
    height: 500
    visible: false

    property string section: "wallpaper"
    property string wallpaperDir: "/home/pucas02/Pictures/Wallpapers"
    property string appliedWallpaper: ""

    property string pfpDir: "/home/pucas02/Pictures/Avatars"
    property string pfpStatePath: "/home/pucas02/.cache/qs-pfp-path"
    property string pfpPath: ""

    function setPfp(path) {
        settingsWin.pfpPath = path
        savePfpProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + settingsWin.pfpStatePath + "\" <<'PFP_EOF'\n" + path + "\nPFP_EOF\n"]
        savePfpProc.running = false
        savePfpProc.running = true
    }

    readonly property string defaultStartIcon: "󰣇"
    property string startIconDir: "/home/pucas02/Pictures/StartIcon"
    property string startIconStatePath: "/home/pucas02/.cache/qs-start-icon-path"
    property string startIconPath: ""

    function setStartIconImage(path) {
        settingsWin.startIconPath = path
        saveStartIconProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + settingsWin.startIconStatePath + "\" <<'ICON_EOF'\n" + path + "\nICON_EOF\n"]
        saveStartIconProc.running = false
        saveStartIconProc.running = true
    }

    property string monitorsLuaPath: "/home/pucas02/.config/hypr/monitors.lua"
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
            ensureWallpaperDirProc.running = false; ensureWallpaperDirProc.running = true
            ensurePfpDirProc.running = false; ensurePfpDirProc.running = true
            ensureStartIconDirProc.running = false; ensureStartIconDirProc.running = true
            if (settingsWin.section === "monitors") settingsWin.refreshMonitors()
        }
    }

    onSectionChanged: if (section === "monitors") refreshMonitors()

    Component.onCompleted: { loadPfpProc.running = true; loadStartIconProc.running = true }

    Process {
        id: floatProc
        command: ["hyprctl", "dispatch", "setfloating", "title:qs-settings"]
    }

    Process {
        id: wallpaperProc
        command: ["awww", "img", settingsWin.appliedWallpaper]
        running: false
    }

    Process {
        id: ensureWallpaperDirProc
        command: ["mkdir", "-p", settingsWin.wallpaperDir]
        running: false
        onExited: {
            wallpaperModel.folder = ""
            wallpaperModel.folder = Qt.binding(function() { return "file://" + settingsWin.wallpaperDir })
        }
    }

    Process {
        id: openWallpaperDirProc
        command: ["nautilus", settingsWin.wallpaperDir]
        running: false
    }

    Process {
        id: ensurePfpDirProc
        command: ["mkdir", "-p", settingsWin.pfpDir]
        running: false
        onExited: {
            pfpModel.folder = ""
            pfpModel.folder = Qt.binding(function() { return "file://" + settingsWin.pfpDir })
        }
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
        onExited: {
            startIconModel.folder = ""
            startIconModel.folder = Qt.binding(function() { return "file://" + settingsWin.startIconDir })
        }
    }

    Process {
        id: openStartIconDirProc
        command: ["nautilus", settingsWin.startIconDir]
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

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "settings"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "monospace"
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

                    NavItem { sym: "󰀄"; label: "profile"; target: "profile" }
                    NavItem { sym: "󰸉"; label: "wallpaper"; target: "wallpaper" }
                    NavItem { sym: "󰍹"; label: "monitors"; target: "monitors" }
                    NavItem { sym: "󰕾"; label: "audio"; target: "audio" }
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height

                Item {
                    id: profileSection
                    anchors.fill: parent
                    opacity: settingsWin.section === "profile" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real slideY: settingsWin.section === "profile" ? 0 : 10
                    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: profileSection.slideY }

                    Item {
                        id: pfpHeader
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: "profile"
                            color: "#ffffff"
                            font.pixelSize: 13; font.family: "monospace"
                        }

                        Text {
                            anchors { right: openPfpFolderBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                            text: settingsWin.pfpDir
                            color: "#444444"
                            font.pixelSize: 9; font.family: "monospace"
                        }

                        Item {
                            id: openPfpFolderBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            width: 28; height: 22

                            Canvas {
                                id: openPfpFolderCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 4, w = width, h = height, hp = openPfpFolderCanvas.hp
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
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                        ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝰"
                                color: openPfpFolderArea.containsMouse ? "#ffffff" : "#999999"
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: openPfpFolderArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: openPfpFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    ensurePfpDirProc.running = false
                                    ensurePfpDirProc.running = true
                                    openPfpDirProc.running = false
                                    openPfpDirProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
                        }
                    }

                    Item {
                        id: startIconRow
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 108

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
                        }

                        Text {
                            anchors { left: parent.left; top: parent.top; topMargin: 12; leftMargin: 16 }
                            text: "start button icon"
                            color: "#999999"
                            font.pixelSize: 11; font.family: "monospace"
                        }

                        Text {
                            anchors { right: startIconFolderBtn.left; top: parent.top; topMargin: 12; rightMargin: 10 }
                            text: settingsWin.startIconDir
                            color: "#444444"
                            font.pixelSize: 9; font.family: "monospace"
                        }

                        Item {
                            id: startIconFolderBtn
                            anchors { right: parent.right; top: parent.top; topMargin: 8; rightMargin: 16 }
                            width: 28; height: 22

                            Canvas {
                                id: startIconFolderCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 4, w = width, h = height, hp = startIconFolderCanvas.hp
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
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                        ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝰"
                                color: startIconFolderArea.containsMouse ? "#ffffff" : "#999999"
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: startIconFolderArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: startIconFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    ensureStartIconDirProc.running = false
                                    ensureStartIconDirProc.running = true
                                    openStartIconDirProc.running = false
                                    openStartIconDirProc.running = true
                                }
                            }
                        }

                        FolderListModel {
                            id: startIconModel
                            folder: "file://" + settingsWin.startIconDir
                            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.svg", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.SVG"]
                            showDirs: false
                        }

                        ListView {
                            id: startIconListView
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top; topMargin: 36; bottomMargin: 12; leftMargin: 16; rightMargin: 16 }
                            orientation: ListView.Horizontal
                            spacing: 8
                            clip: true

                            model: startIconModel
                            delegate: Item {
                                id: startIconTile
                                width: 60; height: 60
                                readonly property bool selected: settingsWin.startIconPath === model.filePath

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#242424"
                                }

                                Image {
                                    anchors { fill: parent; margins: 8 }
                                    source: "file://" + model.filePath
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: startIconTile.selected ? "#39c5bb" : "#2a2a2a"
                                    border.width: startIconTile.selected ? 2 : 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWin.setStartIconImage(model.filePath)
                                }
                            }

                            header: Item {
                                width: 60; height: 60
                                readonly property bool selected: settingsWin.startIconPath === ""

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#242424"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: settingsWin.defaultStartIcon
                                    color: "#39c5bb"
                                    font.pixelSize: 20
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: parent.selected ? "#39c5bb" : "#2a2a2a"
                                    border.width: parent.selected ? 2 : 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWin.setStartIconImage("")
                                }
                            }

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 70 }
                                visible: startIconModel.count === 0
                                text: "no images found in " + settingsWin.startIconDir
                                color: "#444444"
                                font.pixelSize: 10; font.family: "monospace"
                            }
                        }
                    }

                    FolderListModel {
                        id: pfpModel
                        folder: "file://" + settingsWin.pfpDir
                        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
                        showDirs: false
                    }

                    GridView {
                        anchors { top: pfpHeader.bottom; bottom: startIconRow.top; left: parent.left; right: parent.right; margins: 10 }
                        cellWidth: 110; cellHeight: 110
                        clip: true
                        model: pfpModel

                        delegate: Item {
                            id: pfpTileRoot
                            width: 110; height: 110
                            readonly property bool selected: settingsWin.pfpPath === model.filePath

                            Item {
                                id: pfpTile
                                anchors.fill: parent
                                anchors.margins: 8

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#242424"
                                }

                                Image {
                                    id: pfpTileImage
                                    visible: false
                                    source: "file://" + model.filePath
                                    asynchronous: true
                                    onStatusChanged: if (status === Image.Ready) pfpTileCanvas.requestPaint()
                                }

                                Canvas {
                                    id: pfpTileCanvas
                                    anchors.fill: parent
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        if (pfpTileImage.status !== Image.Ready) return
                                        var iw = pfpTileImage.sourceSize.width, ih = pfpTileImage.sourceSize.height
                                        if (iw <= 0 || ih <= 0) return
                                        var targetAspect = width / height
                                        var srcAspect = iw / ih
                                        var sx, sy, sw, sh
                                        if (srcAspect > targetAspect) {
                                            sh = ih; sw = ih * targetAspect; sx = (iw - sw) / 2; sy = 0
                                        } else {
                                            sw = iw; sh = iw / targetAspect; sx = 0; sy = (ih - sh) / 2
                                        }
                                        ctx.save()
                                        ctx.beginPath()
                                        ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2)
                                        ctx.closePath()
                                        ctx.clip()
                                        ctx.drawImage(pfpTileImage, sx, sy, sw, sh, 0, 0, width, height)
                                        ctx.restore()
                                    }
                                }
                            }

                            Rectangle {
                                z: 10
                                anchors.fill: pfpTile
                                radius: width / 2
                                color: "transparent"
                                border.color: pfpTileRoot.selected ? "#39c5bb" : "#2a2a2a"
                                border.width: pfpTileRoot.selected ? 2 : 1
                            }

                            MouseArea {
                                anchors.fill: pfpTile
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.setPfp(model.filePath)
                            }
                        }
                    }

                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: pfpHeader.bottom; bottom: startIconRow.top }
                        verticalAlignment: Text.AlignVCenter
                        visible: pfpModel.count === 0
                        text: "no images found\n" + settingsWin.pfpDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    id: wallpaperSection
                    anchors.fill: parent
                    opacity: settingsWin.section === "wallpaper" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real slideY: settingsWin.section === "wallpaper" ? 0 : 10
                    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: wallpaperSection.slideY }

                    Item {
                        id: wpHeader
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: "wallpaper"
                            color: "#ffffff"
                            font.pixelSize: 13; font.family: "monospace"
                        }

                        Text {
                            anchors { right: openFolderBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                            text: settingsWin.wallpaperDir
                            color: "#444444"
                            font.pixelSize: 9; font.family: "monospace"
                        }

                        Item {
                            id: openFolderBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            width: 28; height: 22

                            Canvas {
                                id: openFolderCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 4, w = width, h = height, hp = openFolderCanvas.hp
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
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                        ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰝰"
                                color: openFolderArea.containsMouse ? "#ffffff" : "#999999"
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: openFolderArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: openFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    ensureWallpaperDirProc.running = false
                                    ensureWallpaperDirProc.running = true
                                    openWallpaperDirProc.running = false
                                    openWallpaperDirProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
                        }
                    }

                    FolderListModel {
                        id: wallpaperModel
                        folder: "file://" + settingsWin.wallpaperDir
                        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
                        showDirs: false
                    }

                    GridView {
                        anchors { top: wpHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 10 }
                        cellWidth: 160; cellHeight: 110
                        clip: true
                        model: wallpaperModel

                        delegate: Item {
                            width: 160; height: 110

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "#242424"
                                border.color: settingsWin.appliedWallpaper === model.filePath ? "#39c5bb" : "#2a2a2a"
                                border.width: settingsWin.appliedWallpaper === model.filePath ? 2 : 1
                                clip: true

                                Image {
                                    anchors { fill: parent; bottomMargin: 20 }
                                    source: "file://" + model.filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                    height: 20
                                    color: "#99000000"

                                    Text {
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 4; rightMargin: 4 }
                                        text: model.fileName
                                        color: "#cccccc"
                                        font.pixelSize: 9; font.family: "monospace"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        settingsWin.appliedWallpaper = model.filePath
                                        wallpaperProc.running = false
                                        wallpaperProc.running = true
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperModel.count === 0
                        text: "no images found\n" + settingsWin.wallpaperDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    id: monitorsSection
                    anchors.fill: parent
                    opacity: settingsWin.section === "monitors" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real slideY: settingsWin.section === "monitors" ? 0 : 10
                    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: monitorsSection.slideY }

                    component MonBtn: Item {
                        property string label: ""
                        property bool active: false
                        signal clicked()
                        width: 72; height: 24
                        onActiveChanged: monBtnCanvas.requestPaint()

                        Canvas {
                            id: monBtnCanvas
                            anchors.fill: parent
                            property real hp: 0.0
                            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onHpChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cut = 5, w = width, h = height, ta = parent.active ? 1.0 : Math.max(hp, 0)
                                function drawShape() {
                                    ctx.beginPath()
                                    ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h-cut)
                                    ctx.lineTo(w-cut,h); ctx.lineTo(0,h); ctx.lineTo(0,cut); ctx.closePath()
                                }
                                drawShape()
                                var base = ctx.createLinearGradient(0,0,0,h)
                                base.addColorStop(0,"#3d3d3d"); base.addColorStop(0.08,"#2a2a2a")
                                base.addColorStop(0.5,"#303030"); base.addColorStop(1.0,"#3a3a3a")
                                ctx.fillStyle = base; ctx.fill()
                                if (ta > 0) {
                                    drawShape()
                                    var teal = ctx.createLinearGradient(0,0,0,h)
                                    teal.addColorStop(0,"#80e0e0"); teal.addColorStop(0.08,"#39c5bb")
                                    teal.addColorStop(0.5,"#2a8a8a"); teal.addColorStop(1.0,"#3a6a6a")
                                    ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                }
                                ctx.beginPath(); ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h*0.62)
                                ctx.lineTo(0,h*0.62); ctx.lineTo(0,cut); ctx.closePath()
                                var gloss = ctx.createLinearGradient(0,0,0,h*0.62)
                                gloss.addColorStop(0,"rgba(255,255,255,"+(0.12+ta*0.2)+")")
                                gloss.addColorStop(1,"rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss; ctx.fill()
                                ctx.beginPath(); ctx.moveTo(cut,0.5); ctx.lineTo(w,0.5)
                                ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.label
                            color: monBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
                            font.pixelSize: 10; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea {
                            id: monBtnArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: monBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                            onClicked: parent.clicked()
                        }
                    }

                    Item {
                        id: monHeader
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44
                        z: 5

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: "monitors"
                            color: "#ffffff"
                            font.pixelSize: 13; font.family: "monospace"
                        }

                        Row {
                            id: monActionRow
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            spacing: 6

                            MonBtn {
                                label: "refresh"
                                active: settingsWin.monitorsRefreshed
                                onClicked: settingsWin.refreshMonitors()
                            }
                            MonBtn {
                                label: "apply"
                                active: settingsWin.monitorsApplied
                                onClicked: settingsWin.applyMonitors()
                            }
                            MonBtn {
                                label: "save"
                                active: settingsWin.monitorsSaved
                                onClicked: settingsWin.saveMonitors()
                            }
                        }

                        Item {
                            id: modeDropdown
                            anchors { right: monActionRow.left; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                            width: 168; height: 24

                            Canvas {
                                id: modeDropdownCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 5, w = width, h = height, ta = modeDropdown.open ? 1.0 : Math.max(hp, 0)
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

                            property bool open: false
                            onOpenChanged: modeDropdownCanvas.requestPaint()

                            Text {
                                anchors { left: parent.left; right: modeArrow.left; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 4 }
                                text: settingsWin.selectedMonitor
                                    ? (settingsWin.selectedMonitor.width + "x" + settingsWin.selectedMonitor.height + "@" + settingsWin.selectedMonitor.refreshRate.toFixed(2))
                                    : "select a monitor"
                                color: settingsWin.selectedMonitor ? "#dddddd" : "#666666"
                                font.pixelSize: 10; font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                id: modeArrow
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                                text: modeDropdown.open ? "▲" : "▼"
                                color: "#888888"
                                font.pixelSize: 8
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: settingsWin.selectedMonitor ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onContainsMouseChanged: modeDropdownCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    if (settingsWin.selectedMonitor) modeDropdown.open = !modeDropdown.open
                                }
                            }

                            Rectangle {
                                id: modeListBg
                                visible: modeDropdown.open && settingsWin.selectedMonitor !== null
                                anchors { top: parent.bottom; left: parent.left; topMargin: 4 }
                                width: 190
                                height: Math.min(200, modeListView.contentHeight + 8)
                                color: "#1a1a1a"
                                border.color: "#39c5bb"
                                border.width: 1
                                z: 100

                                ListView {
                                    id: modeListView
                                    anchors { fill: parent; margins: 4 }
                                    clip: true
                                    model: settingsWin.selectedMonitor ? settingsWin.selectedMonitor.availableModes : []

                                    delegate: Item {
                                        id: modeItem
                                        required property string modelData
                                        width: modeListView.width
                                        height: 22

                                        Rectangle {
                                            anchors.fill: parent
                                            color: modeItemArea.containsMouse ? "#242424" : "transparent"
                                        }

                                        Text {
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 6 }
                                            text: modeItem.modelData.replace("Hz", "")
                                            color: modeItemArea.containsMouse ? "#ffffff" : "#cccccc"
                                            font.pixelSize: 10; font.family: "monospace"
                                        }

                                        MouseArea {
                                            id: modeItemArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var m = modeItem.modelData.match(/(\d+)x(\d+)@([\d.]+)/)
                                                if (m && settingsWin.selectedMonitor) {
                                                    settingsWin.setMonitorMode(settingsWin.selectedMonitor.name, parseInt(m[1]), parseInt(m[2]), parseFloat(m[3]))
                                                }
                                                modeDropdown.open = false
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
                        }
                    }

                    Item {
                        id: monitorsCanvas
                        anchors { top: monHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 14 }

                        readonly property real padding: 24
                        readonly property real minX: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.min(a, m.x), Infinity) : 0
                        readonly property real minY: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.min(a, m.y), Infinity) : 0
                        readonly property real maxX: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.max(a, m.x + m.width), -Infinity) : 1
                        readonly property real maxY: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.max(a, m.y + m.height), -Infinity) : 1
                        readonly property real totalW: Math.max(1, maxX - minX)
                        readonly property real totalH: Math.max(1, maxY - minY)
                        readonly property real scaleFactor: settingsWin.monitors.length
                            ? Math.min((width - padding * 2) / totalW, (height - padding * 2) / totalH)
                            : 1

                        readonly property real snapPx: 10

                        function toPixelX(modelX) { return monitorsCanvas.padding + (modelX - monitorsCanvas.minX) * monitorsCanvas.scaleFactor }
                        function toPixelY(modelY) { return monitorsCanvas.padding + (modelY - monitorsCanvas.minY) * monitorsCanvas.scaleFactor }
                        function toModelX(pixelX) { return monitorsCanvas.minX + (pixelX - monitorsCanvas.padding) / monitorsCanvas.scaleFactor }
                        function toModelY(pixelY) { return monitorsCanvas.minY + (pixelY - monitorsCanvas.padding) / monitorsCanvas.scaleFactor }

                        function cloneMonitors() {
                            return settingsWin.monitors.map(function(m) {
                                var c = {}
                                for (var k in m) c[k] = m[k]
                                return c
                            })
                        }

                        function snapPos(mon, rawX, rawY, others) {
                            var thresholdModel = monitorsCanvas.snapPx / monitorsCanvas.scaleFactor
                            var bestX = rawX, bestXDist = thresholdModel
                            var bestY = rawY, bestYDist = thresholdModel
                            for (var i = 0; i < others.length; i++) {
                                var o = others[i]
                                if (o === mon) continue
                                var xCandidates = [o.x - mon.width, o.x, o.x + o.width - mon.width, o.x + o.width, o.x + o.width / 2 - mon.width / 2]
                                for (var xi = 0; xi < xCandidates.length; xi++) {
                                    var dx = Math.abs(rawX - xCandidates[xi])
                                    if (dx < bestXDist) { bestXDist = dx; bestX = xCandidates[xi] }
                                }
                                var yCandidates = [o.y - mon.height, o.y, o.y + o.height - mon.height, o.y + o.height, o.y + o.height / 2 - mon.height / 2]
                                for (var yi = 0; yi < yCandidates.length; yi++) {
                                    var dy = Math.abs(rawY - yCandidates[yi])
                                    if (dy < bestYDist) { bestYDist = dy; bestY = yCandidates[yi] }
                                }
                            }
                            return { x: bestX, y: bestY }
                        }

                        function liveSnapPixels(box, px, py) {
                            var bestX = px, bestXDist = monitorsCanvas.snapPx
                            var bestY = py, bestYDist = monitorsCanvas.snapPx
                            for (var i = 0; i < monRepeater.count; i++) {
                                var other = monRepeater.itemAt(i)
                                if (!other || other === box) continue
                                var ox = other.x, oy = other.y, ow = other.width, oh = other.height
                                var xCandidates = [ox - box.width, ox, ox + ow - box.width, ox + ow, ox + ow / 2 - box.width / 2]
                                for (var xi = 0; xi < xCandidates.length; xi++) {
                                    var dx = Math.abs(px - xCandidates[xi])
                                    if (dx < bestXDist) { bestXDist = dx; bestX = xCandidates[xi] }
                                }
                                var yCandidates = [oy - box.height, oy, oy + oh - box.height, oy + oh, oy + oh / 2 - box.height / 2]
                                for (var yi = 0; yi < yCandidates.length; yi++) {
                                    var dy = Math.abs(py - yCandidates[yi])
                                    if (dy < bestYDist) { bestYDist = dy; bestY = yCandidates[yi] }
                                }
                            }
                            return { x: bestX, y: bestY }
                        }

                        function moveMonitor(index, rawModelX, rawModelY) {
                            var arr = monitorsCanvas.cloneMonitors()
                            var mon = arr[index]
                            var snapped = monitorsCanvas.snapPos(mon, rawModelX, rawModelY, arr)
                            var boxW = Math.max(50, mon.width * monitorsCanvas.scaleFactor)
                            var boxH = Math.max(36, mon.height * monitorsCanvas.scaleFactor)
                            var px = Math.max(0, Math.min(monitorsCanvas.width - boxW, monitorsCanvas.toPixelX(snapped.x)))
                            var py = Math.max(0, Math.min(monitorsCanvas.height - boxH, monitorsCanvas.toPixelY(snapped.y)))
                            mon.x = Math.round(monitorsCanvas.toModelX(px))
                            mon.y = Math.round(monitorsCanvas.toModelY(py))
                            settingsWin.monitors = arr
                        }

                        function scaleMonitor(index, delta) {
                            var arr = monitorsCanvas.cloneMonitors()
                            arr[index].scale = Math.max(0.5, Math.min(3.0, arr[index].scale + delta))
                            settingsWin.monitors = arr
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#111111"
                            border.color: "#2a2a2a"
                            border.width: 1
                        }

                        Repeater {
                            id: monRepeater
                            model: settingsWin.monitors

                            delegate: Item {
                                id: monBox
                                required property var modelData
                                required property int index
                                readonly property bool selected: settingsWin.selectedMonitorName === modelData.name
                                x: monitorsCanvas.toPixelX(modelData.x)
                                y: monitorsCanvas.toPixelY(modelData.y)
                                width: Math.max(50, modelData.width * monitorsCanvas.scaleFactor)
                                height: Math.max(36, modelData.height * monitorsCanvas.scaleFactor)
                                z: monDragHandler.active ? 10 : (modelData.focused ? 2 : 1)

                                Rectangle {
                                    anchors.fill: parent
                                    color: monDragHandler.active ? "#2a4a48" : (monHoverHandler.hovered ? "#243030" : "#1e2424")
                                    border.color: monDragHandler.active || monHoverHandler.hovered || monBox.selected ? "#39c5bb" : "#3a3a3a"
                                    border.width: monDragHandler.active || monBox.selected ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: monBox.modelData.name
                                            color: "#e0e0e0"
                                            font.pixelSize: 11; font.family: "monospace"
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: monBox.modelData.width + "x" + monBox.modelData.height + " @" + monBox.modelData.scale.toFixed(2) + "x"
                                            color: "#777777"
                                            font.pixelSize: 9; font.family: "monospace"
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: monHoverHandler
                                    cursorShape: Qt.SizeAllCursor
                                }

                                TapHandler {
                                    onTapped: settingsWin.selectedMonitorName = monBox.modelData.name
                                }

                                WheelHandler {
                                    onWheel: event => {
                                        var d = event.angleDelta.y > 0 ? 0.05 : -0.05
                                        monitorsCanvas.scaleMonitor(monBox.index, d)
                                    }
                                }

                                DragHandler {
                                    id: monDragHandler
                                    target: null
                                    property real dragStartPixelX: 0
                                    property real dragStartPixelY: 0
                                    onActiveChanged: {
                                        if (active) {
                                            dragStartPixelX = monBox.x
                                            dragStartPixelY = monBox.y
                                        } else {
                                            var rawX = monitorsCanvas.toModelX(monBox.x)
                                            var rawY = monitorsCanvas.toModelY(monBox.y)
                                            monitorsCanvas.moveMonitor(monBox.index, rawX, rawY)
                                        }
                                    }
                                    onTranslationChanged: {
                                        if (!active) return
                                        var px = Math.max(0, Math.min(monitorsCanvas.width - monBox.width, dragStartPixelX + translation.x))
                                        var py = Math.max(0, Math.min(monitorsCanvas.height - monBox.height, dragStartPixelY + translation.y))
                                        var snapped = monitorsCanvas.liveSnapPixels(monBox, px, py)
                                        monBox.x = snapped.x
                                        monBox.y = snapped.y
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: settingsWin.monitors.length === 0 && settingsWin.monitorsError === ""
                            text: "loading monitors..."
                            color: "#444444"
                            font.pixelSize: 11; font.family: "monospace"
                        }

                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                            visible: settingsWin.monitorsError !== ""
                            text: settingsWin.monitorsError
                            color: "#ff6b6b"
                            font.pixelSize: 10; font.family: "monospace"
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    id: audioSection
                    anchors.fill: parent
                    opacity: settingsWin.section === "audio" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real slideY: settingsWin.section === "audio" ? 0 : 10
                    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: audioSection.slideY }

                    PwObjectTracker {
                        objects: Pipewire.nodes.values
                    }

                    property var outputDevices: Pipewire.ready
                        ? Pipewire.nodes.values.filter(function(n) { return !n.isStream && (n.type & PwNodeType.AudioSink) })
                        : []
                    property var inputDevices: Pipewire.ready
                        ? Pipewire.nodes.values.filter(function(n) { return !n.isStream && (n.type & PwNodeType.AudioSource) })
                        : []
                    property var playbackStreams: Pipewire.ready
                        ? Pipewire.nodes.values.filter(function(n) { return n.isStream && (n.type & PwNodeType.AudioOutStream) })
                        : []

                    component VolumeSlider: Item {
                        property real value: 0
                        property bool muted: false
                        signal moved(real v)
                        height: 20

                        Rectangle {
                            id: sliderTrack
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 5
                            radius: 2.5
                            color: "#2a2a2a"

                            Rectangle {
                                width: sliderTrack.width * Math.max(0, Math.min(1, parent.parent.value))
                                height: parent.height
                                radius: parent.radius
                                color: parent.parent.muted ? "#555555" : "#39c5bb"
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                        }

                        MouseArea {
                            anchors { fill: parent; margins: -4 }
                            cursorShape: Qt.PointingHandCursor
                            function updateFromX(mx) { moved(Math.max(0, Math.min(1, mx / width))) }
                            onPressed: mouse => updateFromX(mouse.x)
                            onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
                        }
                    }

                    component MuteBtn: Item {
                        property bool muted: false
                        signal toggled()
                        width: 26; height: 26

                        Text {
                            anchors.centerIn: parent
                            text: parent.muted ? "󰝟" : "󰕾"
                            color: muteArea.containsMouse ? "#ffffff" : (parent.muted ? "#ff6b6b" : "#999999")
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: muteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.toggled()
                        }
                    }

                    component DeviceRow: Item {
                        property var node: null
                        property bool active: false
                        signal selected()
                        width: parent ? parent.width : 0
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            color: deviceRowArea.containsMouse ? "#242424" : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Rectangle {
                                width: 2; height: parent.height * 0.55
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                color: "#39c5bb"
                                opacity: parent.parent.active ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14; right: parent.right; rightMargin: 8 }
                                text: parent.parent.node ? (parent.parent.node.description || parent.parent.node.nickname || parent.parent.node.name) : ""
                                color: parent.parent.active ? "#ffffff" : "#999999"
                                font.pixelSize: 11; font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: deviceRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.selected()
                        }
                    }

                    Item {
                        id: audioHeader
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: "audio"
                            color: "#ffffff"
                            font.pixelSize: 13; font.family: "monospace"
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
                        }
                    }

                    Flickable {
                        anchors { top: audioHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                        contentWidth: width
                        contentHeight: audioContent.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: audioContent
                            width: parent.width
                            spacing: 0

                            Item {
                                width: parent.width
                                height: 26
                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                                    text: "output device"
                                    color: "#666666"
                                    font.pixelSize: 10; font.family: "monospace"
                                }
                            }

                            Column {
                                width: parent.width
                                Repeater {
                                    model: audioSection.outputDevices
                                    delegate: DeviceRow {
                                        required property var modelData
                                        node: modelData
                                        active: Pipewire.defaultAudioSink === modelData
                                        onSelected: Pipewire.preferredDefaultAudioSink = modelData
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 40
                                visible: Pipewire.defaultAudioSink !== null

                                MuteBtn {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                                    muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                                    onToggled: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                }

                                VolumeSlider {
                                    anchors { left: parent.left; right: outputPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 44; rightMargin: 10 }
                                    value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                                    muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                                    onMoved: v => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v }
                                }

                                Text {
                                    id: outputPctText
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                                    width: 34
                                    horizontalAlignment: Text.AlignRight
                                    text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                                    color: "#999999"
                                    font.pixelSize: 10; font.family: "monospace"
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

                            Item {
                                width: parent.width
                                height: 26
                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                                    text: "input device"
                                    color: "#666666"
                                    font.pixelSize: 10; font.family: "monospace"
                                }
                            }

                            Column {
                                width: parent.width
                                Repeater {
                                    model: audioSection.inputDevices
                                    delegate: DeviceRow {
                                        required property var modelData
                                        node: modelData
                                        active: Pipewire.defaultAudioSource === modelData
                                        onSelected: Pipewire.preferredDefaultAudioSource = modelData
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 40
                                visible: Pipewire.defaultAudioSource !== null

                                MuteBtn {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                                    muted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
                                    onToggled: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                                }

                                VolumeSlider {
                                    anchors { left: parent.left; right: inputPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 44; rightMargin: 10 }
                                    value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
                                    muted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
                                    onMoved: v => { if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = v }
                                }

                                Text {
                                    id: inputPctText
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                                    width: 34
                                    horizontalAlignment: Text.AlignRight
                                    text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "--"
                                    color: "#999999"
                                    font.pixelSize: 10; font.family: "monospace"
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

                            Item {
                                width: parent.width
                                height: 26
                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                                    text: "applications"
                                    color: "#666666"
                                    font.pixelSize: 10; font.family: "monospace"
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: audioSection.playbackStreams
                                    delegate: Item {
                                        id: streamRow
                                        required property var modelData
                                        width: parent ? parent.width : 0
                                        height: 40

                                        Text {
                                            anchors { left: parent.left; top: parent.top; leftMargin: 16; topMargin: 2; right: parent.right; rightMargin: 16 }
                                            text: streamRow.modelData.properties["application.name"] || streamRow.modelData.description || streamRow.modelData.name
                                            color: "#cccccc"
                                            font.pixelSize: 10; font.family: "monospace"
                                            elide: Text.ElideRight
                                        }

                                        MuteBtn {
                                            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 2 }
                                            width: 22; height: 18
                                            muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                            onToggled: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                                        }

                                        VolumeSlider {
                                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40; rightMargin: 46; bottomMargin: 4 }
                                            value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                                            muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                            onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
                                        }

                                        Text {
                                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 4 }
                                            width: 34
                                            horizontalAlignment: Text.AlignRight
                                            text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                                            color: "#666666"
                                            font.pixelSize: 9; font.family: "monospace"
                                        }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: audioSection.playbackStreams.length === 0
                                    text: "nothing playing"
                                    color: "#444444"
                                    font.pixelSize: 10; font.family: "monospace"
                                    topPadding: 10
                                }
                            }

                            Item { width: parent.width; height: 16 }
                        }
                    }
                }
            }
        }
    }
}

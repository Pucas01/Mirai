import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Io

Variants {
    id: shellRoot
    model: Quickshell.screens

    property var pendingToastNotif: null
    property int globalNotifCount: 0
    property string pendingScreenshotPath: ""
    property int screenshotTrigger: 0

    PanelWindow {
        id: panel
        property var modelData
        screen: modelData

        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property var screenWorkspaces: Hyprland.workspaces.values.filter(w => w.monitor === hyprMonitor)
        property var preferredPlayer: null
        property var activePlayer: {
            var players = Mpris.players.values
            if (preferredPlayer && players.indexOf(preferredPlayer) !== -1) return preferredPlayer
            return players.find(p => p.isPlaying) ?? (players.length > 0 ? players[0] : null)
        }

        NotificationServer {
            id: notifServer
            keepOnReload: true
            onNotification: notif => {
                if (notif.appName === "qs-screenshot") {
                    shellRoot.pendingScreenshotPath = notif.body
                    shellRoot.screenshotTrigger += 1
                    return
                }
                notif.tracked = true
                shellRoot.globalNotifCount += 1
                shellRoot.pendingToastNotif = notif
            }
        }

        Connections {
            target: notifServer.trackedNotifications
            function onRowsRemoved(parent, first, last) { shellRoot.globalNotifCount = Math.max(0, shellRoot.globalNotifCount - (last - first + 1)) }
            function onModelReset() { shellRoot.globalNotifCount = 0 }
        }

        Connections {
            target: shellRoot
            function onScreenshotTriggerChanged() {
                if (!shellRoot.pendingScreenshotPath) return
                if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
                var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
                var barBottom = barBg.mapToGlobal(0, barBg.height)
                screenshotWin.show(
                    wsCenter.x - screenshotWin.width / 2,
                    barBottom.y + 8,
                    shellRoot.pendingScreenshotPath,
                    shellRoot.screenshotTrigger
                )
            }
            function onPendingToastNotifChanged() {
                if (!shellRoot.pendingToastNotif) return
                if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
                var pos = barBg.mapToGlobal(barBg.width - toastWin.width - 16, barBg.height + 8)
                toastWin.show(pos.x, pos.y, shellRoot.pendingToastNotif)
            }
        }

        property bool audioOsdArmed: false
        Timer { interval: 1500; running: true; onTriggered: panel.audioOsdArmed = true }

        property string netType: ""
        property bool netConnected: false

        property real brightness: 1
        property bool brightnessAvailable: false
        property bool brightnessOsdArmed: false
        Timer { interval: 1500; running: true; onTriggered: panel.brightnessOsdArmed = true }

        function refreshBrightness() {
            brightnessGetProc.running = false
            brightnessGetProc.running = true
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshBrightness()
        }

        Process {
            id: brightnessGetProc
            command: ["brightnessctl", "-m"]
            onExited: code => { if (code !== 0) panel.brightnessAvailable = false }
            stdout: StdioCollector {
                onStreamFinished: {
                    var line = text.trim().split("\n")[0] || ""
                    var parts = line.split(",")
                    if (parts.length < 5) { panel.brightnessAvailable = false; return }
                    var cur = parseInt(parts[2])
                    var max = parseInt(parts[4])
                    if (!max) { panel.brightnessAvailable = false; return }
                    panel.brightnessAvailable = true
                    var v = cur / max
                    if (Math.abs(v - panel.brightness) > 0.001) {
                        panel.brightness = v
                        panel.showBrightnessOsd()
                    }
                }
            }
        }

        function setBrightness(v) {
            v = Math.max(0, Math.min(1, v))
            panel.brightness = v
            brightnessSetProc.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]
            brightnessSetProc.running = false
            brightnessSetProc.running = true
        }

        Process {
            id: brightnessSetProc
        }

        function showBrightnessOsd() {
            if (!panel.brightnessAvailable) return
            if (!panel.brightnessOsdArmed) return
            if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
            if (brightnessPopup.sliderActive) return
            var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
            var barBottom = barBg.mapToGlobal(0, barBg.height)
            brightnessOsd.show(wsCenter.x - brightnessOsd.width / 2, barBottom.y + 8)
        }

        property bool weatherLoaded: false
        property string weatherTempC: ""
        property string weatherDesc: ""
        property int weatherCode: 0
        property string weatherFeelsLikeC: ""
        property string weatherHumidity: ""
        property string weatherWindKmph: ""
        property string weatherUvIndex: ""
        property string weatherAreaName: ""
        property var weatherForecast: []

        function refreshWeather() {
            weatherProc.running = false
            weatherProc.running = true
        }

        Timer {
            interval: 900000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshWeather()
        }

        Process {
            id: weatherProc
            command: ["curl", "-s", "--max-time", "5", "wttr.in/?format=j1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(text)
                        var cur = data.current_condition[0]
                        panel.weatherTempC = cur.temp_C
                        panel.weatherDesc = cur.weatherDesc[0].value
                        panel.weatherCode = parseInt(cur.weatherCode)
                        panel.weatherFeelsLikeC = cur.FeelsLikeC
                        panel.weatherHumidity = cur.humidity
                        panel.weatherWindKmph = cur.windspeedKmph
                        panel.weatherUvIndex = cur.uvIndex
                        panel.weatherAreaName = data.nearest_area && data.nearest_area[0]
                            ? data.nearest_area[0].areaName[0].value
                            : ""
                        panel.weatherForecast = data.weather.map(function(d) {
                            var noon = d.hourly.find(function(h) { return h.time === "1200" }) || d.hourly[Math.floor(d.hourly.length / 2)]
                            return {
                                date: d.date,
                                maxTempC: d.maxtempC,
                                minTempC: d.mintempC,
                                code: parseInt(noon.weatherCode),
                                chanceOfRain: noon.chanceofrain,
                                sunrise: d.astronomy[0].sunrise,
                                sunset: d.astronomy[0].sunset
                            }
                        })
                        panel.weatherLoaded = true
                    } catch (e) {
                        panel.weatherLoaded = false
                    }
                }
            }
        }

        function weatherGlyph(code) {
            if ([113].includes(code)) return "󰖙"
            if ([116].includes(code)) return "󰖕"
            if ([119, 122].includes(code)) return "󰖐"
            if ([143, 248, 260].includes(code)) return "󰖑"
            if ([176, 179, 182, 185, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 323, 326, 353, 356, 359, 362, 365, 368, 371].includes(code)) return "󰖗"
            if ([200, 386, 389, 392, 395].includes(code)) return "󰙾"
            if ([227, 230, 329, 332, 335, 338, 350, 374, 377].includes(code)) return "󰼶"
            return "󰖐"
        }

        property string lastPickedColor: ""
        Timer { id: pickedColorResetTimer; interval: 2000; onTriggered: panel.lastPickedColor = "" }

        function pickColor() {
            colorPickerProc.running = false
            colorPickerProc.running = true
        }

        Process {
            id: colorPickerProc
            command: ["hyprpicker", "-a", "-f", "hex"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var hex = text.trim()
                    if (hex !== "") {
                        panel.lastPickedColor = hex
                        pickedColorResetTimer.restart()
                    }
                }
            }
        }

        function refreshNet() {
            netStatusProc.running = false
            netStatusProc.running = true
        }

        Timer {
            interval: 5000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshNet()
        }

        Process {
            id: netStatusProc
            command: ["nmcli", "-t", "-f", "TYPE,ACTIVE", "connection", "show"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let type = ""
                    let up = false
                    const lines = text.split("\n")
                    for (const line of lines) {
                        if (!line.trim()) continue
                        const idx = line.lastIndexOf(":")
                        if (idx === -1) continue
                        const t = line.slice(0, idx)
                        const active = line.slice(idx + 1) === "yes"
                        if (!active) continue
                        if (t === "802-3-ethernet") { type = "ethernet"; up = true; break }
                        if (t === "802-11-wireless" && type === "") { type = "wifi"; up = true }
                    }
                    panel.netType = type
                    panel.netConnected = up
                }
            }
        }

        property var cavaBars: [0, 0, 0, 0, 0, 0, 0]

        Process {
            id: cavaProc
            command: ["cava", "-p", Quickshell.shellPath("bar/cava.conf")]
            running: panel.activePlayer !== null && panel.activePlayer.isPlaying
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    var parts = data.split(";").filter(function(s) { return s.trim() !== "" })
                    if (parts.length === 0) return
                    panel.cavaBars = parts.map(function(s) { return parseInt(s) || 0 })
                }
            }
        }

        function showAudioOsd() {
            if (!panel.audioOsdArmed) return
            if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
            if (audioPopup.sliderActive || startMenu.audioSliderActive) return
            var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
            var barBottom = barBg.mapToGlobal(0, barBg.height)
            audioOsd.show(wsCenter.x - audioOsd.width / 2, barBottom.y + 8)
        }

        Connections {
            target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
            function onVolumeChanged() { panel.showAudioOsd() }
            function onMutedChanged() { panel.showAudioOsd() }
        }

        anchors { top: true; left: true; right: true }
        implicitHeight: 50
        color: "transparent"
        exclusiveZone: 46

        TrayMenu {
            id: trayMenu
        }

        MediaPopup {
            id: mediaPopup
            activePlayer: panel.activePlayer
            preferredPlayer: panel.preferredPlayer
            onPreferredPlayerChanged: panel.preferredPlayer = mediaPopup.preferredPlayer
        }

        ToastWin {
            id: toastWin
        }

        ScreenshotWin {
            id: screenshotWin
        }

        StartMenu {
            id: startMenu
        }

        NotifPopup {
            id: notifPopup
            trackedNotifications: notifServer.trackedNotifications
            notifCount: shellRoot.globalNotifCount
            onNotifCountReset: shellRoot.globalNotifCount = 0
        }

        AudioPopup {
            id: audioPopup
        }

        BrightnessPopup {
            id: brightnessPopup
            brightness: panel.brightness
            onMoved: v => panel.setBrightness(v)
        }

        NetworkPopup {
            id: networkPopup
        }

        WeatherPopup {
            id: weatherPopup
            glyph: panel.weatherGlyph(panel.weatherCode)
            desc: panel.weatherDesc
            tempC: panel.weatherTempC
            feelsLikeC: panel.weatherFeelsLikeC
            humidity: panel.weatherHumidity
            windKmph: panel.weatherWindKmph
            uvIndex: panel.weatherUvIndex
            areaName: panel.weatherAreaName
            forecast: panel.weatherForecast
            glyphFn: panel.weatherGlyph
        }

        AudioOSD {
            id: audioOsd
        }

        BrightnessOSD {
            id: brightnessOsd
            brightness: panel.brightness
        }

        Rectangle {
            id: barBg
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 46

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0;  color: "#3d3d3d" }
                GradientStop { position: 0.08; color: "#2c2c2c" }
                GradientStop { position: 0.5;  color: "#232323" }
                GradientStop { position: 1.0;  color: "#181818" }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: "#5a5a5a"
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.topMargin: 1
                height: 4
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#50505050" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: "#39c5bb"
            }

            Row {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 14 }
                spacing: 10

                Item {
                    id: networkItem
                    width: 35; height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: networkCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 5, w = width, h = height, hp = hoverProgress
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
                        text: panel.netType === "ethernet" ? "󰈀" : (panel.netType === "wifi" ? "󰤨" : "󰤭")
                        font.pixelSize: 14
                        color: networkMouseArea.containsMouse ? "#ffffff" : (panel.netConnected ? "#888888" : "#555555")
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    MouseArea {
                        id: networkMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: networkCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            networkPopup.open(center.x - networkPopup.width / 2, barBottom.y + 6)
                        }
                    }
                }

                Item {
                    id: audioItem
                    width: 35; height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    PwObjectTracker {
                        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
                    }

                    Canvas {
                        id: audioCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 5, w = width, h = height, hp = hoverProgress
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
                        text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "󰝟" : "󰕾"
                        font.pixelSize: 14
                        color: audioMouseArea.containsMouse ? "#ffffff" : "#888888"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    MouseArea {
                        id: audioMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: audioCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            audioPopup.open(center.x - audioPopup.width / 2, barBottom.y + 6)
                        }
                        onWheel: wheel => {
                            if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) return
                            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            var audio = Pipewire.defaultAudioSink.audio
                            audio.volume = Math.max(0, Math.min(1, audio.volume + step))
                        }
                    }
                }

                Item {
                    id: brightnessItem
                    visible: panel.brightnessAvailable
                    width: panel.brightnessAvailable ? 35 : 0
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: brightnessCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 5, w = width, h = height, hp = hoverProgress
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
                        text: "󰃟"
                        font.pixelSize: 14
                        color: brightnessMouseArea.containsMouse ? "#ffffff" : "#888888"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    MouseArea {
                        id: brightnessMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: brightnessCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            brightnessPopup.open(center.x - brightnessPopup.width / 2, barBottom.y + 6)
                        }
                        onWheel: wheel => {
                            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            panel.setBrightness(panel.brightness + step)
                        }
                    }
                }

                Item {
                    id: bellItem
                    width: 35; height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: bellCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 5, w = width, h = height, hp = hoverProgress
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
                        text: "󰂚"
                        font.pixelSize: 14
                        color: bellMouseArea.containsMouse ? "#ffffff" : shellRoot.globalNotifCount > 0 ? "#39c5bb" : "#888888"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Rectangle {
                        visible: shellRoot.globalNotifCount > 0
                        anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                        width: 8; height: 8; radius: 4
                        color: "#ff4444"
                    }

                    MouseArea {
                        id: bellMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: bellCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            notifPopup.open(center.x - notifPopup.width / 2, barBottom.y + 6)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayDelegate
                            required property var modelData
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: trayDelegate.modelData.icon
                                mipmap: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        trayDelegate.modelData.activate()
                                    } else {
                                        var iconCenter = mapToGlobal(width / 2, 0)
                                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                                        trayMenu.targetItem = trayDelegate.modelData
                                        trayMenu.open(iconCenter.x - trayMenu.width / 2, barBottom.y + 6)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        id: dateText
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#777777"
                        font.pixelSize: 15
                        font.family: "monospace"
                        text: Qt.formatDateTime(new Date(), "ddd dd MMM")
                    }

                    Item {
                        width: 16
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: parent.height * 0.7
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#00404040" }
                                GradientStop { position: 0.4; color: "#804a4a4a" }
                                GradientStop { position: 0.6; color: "#804a4a4a" }
                                GradientStop { position: 1.0; color: "#00404040" }
                            }
                        }
                    }

                    Text {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#d0d0d0"
                        font.pixelSize: 15
                        font.family: "monospace"
                        text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            var now = new Date()
                            clockText.text = Qt.formatDateTime(now, "hh:mm:ss")
                            dateText.text = Qt.formatDateTime(now, "ddd dd MMM")
                        }
                    }
                }
            }

            Item {
                id: weatherItem
                anchors { left: wsArea.right; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                visible: panel.weatherLoaded
                width: visible ? weatherRow.width + 20 : 0
                height: 30

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Canvas {
                    id: weatherCanvas
                    anchors.fill: parent
                    property real hoverProgress: 0.0
                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHoverProgressChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cut = 6, w = width, h = height, hp = hoverProgress
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

                Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.weatherGlyph(panel.weatherCode)
                        color: weatherMouseArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.weatherTempC + "°"
                        color: weatherMouseArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 12; font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                }

                MouseArea {
                    id: weatherMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: weatherCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                    onClicked: {
                        var center = mapToGlobal(width / 2, 0)
                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                        weatherPopup.open(center.x - weatherPopup.width / 2, barBottom.y + 6)
                    }
                }
            }

            Item {
                id: colorPickerItem
                anchors { left: weatherItem.right; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                width: panel.lastPickedColor !== "" ? colorPickerRow.width + 20 : 34
                height: 30

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Canvas {
                    id: colorPickerCanvas
                    anchors.fill: parent
                    property real hoverProgress: 0.0
                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHoverProgressChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cut = 6, w = width, h = height, hp = hoverProgress
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

                Row {
                    id: colorPickerRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰈊"
                        color: colorPickerMouseArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: panel.lastPickedColor !== ""
                        width: 12; height: 12
                        radius: 2
                        color: panel.lastPickedColor !== "" ? panel.lastPickedColor : "transparent"
                        border.color: "#00000055"
                        border.width: 1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: panel.lastPickedColor !== ""
                        text: panel.lastPickedColor
                        color: "#cccccc"
                        font.pixelSize: 11; font.family: "monospace"
                    }
                }

                MouseArea {
                    id: colorPickerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: colorPickerCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                    onClicked: panel.pickColor()
                }
            }

            Row {
                anchors { right: wsArea.left; top: parent.top; bottom: parent.bottom }
                spacing: 0
                visible: panel.activePlayer !== null

                Item {
                    id: mediaWidget
                    width: mediaRow.width + 16
                    height: parent.height
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            mediaPopup.open(center.x - mediaPopup.width / 2, barBottom.y + 6)
                        }
                    }

                    Row {
                        id: mediaRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#111111"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: panel.activePlayer ? panel.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: panel.activePlayer && panel.activePlayer.trackArtUrl !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !panel.activePlayer || panel.activePlayer.trackArtUrl === ""
                                text: "♪"
                                color: "#39c5bb"
                                font.pixelSize: 14
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            rightPadding: 6

                            readonly property int maxTextWidth: 220

                            Text {
                                id: mediaTitleText
                                width: Math.min(implicitWidth, parent.maxTextWidth)
                                text: panel.activePlayer ? panel.activePlayer.trackTitle : ""
                                color: "#d0d0d0"
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            Text {
                                id: mediaArtistText
                                width: Math.min(implicitWidth, parent.maxTextWidth)
                                text: panel.activePlayer ? panel.activePlayer.trackArtist : ""
                                color: "#666666"
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideRight
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                        }

                        Row {
                            id: cavaRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1.5
                            height: 30
                            clip: true
                            visible: width > 0
                            width: (panel.activePlayer !== null && panel.activePlayer.isPlaying) ? implicitWidth : 0
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            opacity: (panel.activePlayer !== null && panel.activePlayer.isPlaying) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Repeater {
                                model: panel.cavaBars

                                delegate: Rectangle {
                                    required property var modelData
                                    anchors.bottom: parent.bottom
                                    width: 2
                                    height: Math.max(1.5, (modelData / 100) * 30)
                                    radius: 1
                                    color: "#39c5bb"
                                    Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }

            }

            Item {
                id: wsArea
                anchors.centerIn: parent
                width: wsRow.width + 48
                height: parent.height

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 1
                    height: parent.height * 0.5
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 1
                    height: parent.height * 0.5
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => {
                        const ws = panel.screenWorkspaces
                        const activeIdx = ws.findIndex(w => w.active)
                        if (activeIdx === -1) return
                        const dir = wheel.angleDelta.y > 0 ? 1 : -1
                        const nextId = ws[(activeIdx + dir + ws.length) % ws.length].id
                        Hyprland.dispatch("hl.dsp.focus({workspace=\"" + nextId + "\"})")
                    }
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 5

                Repeater {
                    model: panel.screenWorkspaces

                    delegate: Item {
                        required property var modelData

                        property var toplevels: modelData.toplevels.values
                        property bool occupied: toplevels.length > 0
                        property var activeToplevel: toplevels.find(t => t.activated) || toplevels[0] || null
                        property string appId: {
                            if (!activeToplevel) return ""
                            if (activeToplevel.wayland && activeToplevel.wayland.appId !== "")
                                return activeToplevel.wayland.appId
                            if (activeToplevel.lastIpcObject)
                                return activeToplevel.lastIpcObject["class"] || ""
                            return ""
                        }
                        property var appEntry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null

                        width: occupied ? 34 : (modelData.active ? 24 : 10)
                        height: 28

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Canvas {
                            id: pill
                            anchors.fill: parent
                            visible: parent.occupied

                            property bool active: modelData.active
                            property real activeProgress: active ? 1.0 : 0.0
                            Behavior on activeProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            property real hoverProgress: 0.0
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onActiveProgressChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()
                            onHoverProgressChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var cut = 6
                                var w = width
                                var h = height
                                var ap = activeProgress
                                var hp = hoverProgress
                                var tealAmount = Math.max(ap, hp * (1.0 - ap))

                                function drawShape() {
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0)
                                    ctx.lineTo(w,       0)
                                    ctx.lineTo(w,       h - cut)
                                    ctx.lineTo(w - cut, h)
                                    ctx.lineTo(0,       h)
                                    ctx.lineTo(0,       cut)
                                    ctx.closePath()
                                }

                                drawShape()
                                var base = ctx.createLinearGradient(0, 0, 0, h)
                                base.addColorStop(0,    "#3d3d3d")
                                base.addColorStop(0.08, "#2a2a2a")
                                base.addColorStop(0.5,  "#303030")
                                base.addColorStop(1.0,  "#3a3a3a")
                                ctx.fillStyle = base
                                ctx.fill()

                                if (tealAmount > 0) {
                                    drawShape()
                                    var teal = ctx.createLinearGradient(0, 0, 0, h)
                                    teal.addColorStop(0,    "#80e0e0")
                                    teal.addColorStop(0.08, "#39c5bb")
                                    teal.addColorStop(0.5,  "#2a8a8a")
                                    teal.addColorStop(1.0,  "#3a6a6a")
                                    ctx.globalAlpha = tealAmount
                                    ctx.fillStyle = teal
                                    ctx.fill()
                                    ctx.globalAlpha = 1.0
                                }

                                ctx.beginPath()
                                ctx.moveTo(cut, 0)
                                ctx.lineTo(w,   0)
                                ctx.lineTo(w,   h * 0.62)
                                ctx.lineTo(0,   h * 0.62)
                                ctx.lineTo(0,   cut)
                                ctx.closePath()
                                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                gloss.addColorStop(0, "rgba(255,255,255," + (0.30 + tealAmount * 0.24) + ")")
                                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss
                                ctx.fill()

                                ctx.beginPath()
                                ctx.moveTo(cut, 0.5)
                                ctx.lineTo(w,   0.5)
                                ctx.strokeStyle = tealAmount > 0.5 ? "#c0f4f4" : "#646464"
                                ctx.lineWidth = 1
                                ctx.stroke()
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            mipmap: true
                            visible: occupied && appEntry !== null && appEntry.icon !== ""
                            source: appEntry && appEntry.icon !== "" ? "image://icon/" + appEntry.icon : ""
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: modelData.active ? 8 : 5
                            height: modelData.active ? 8 : 5
                            radius: height / 2
                            color: modelData.active ? "#39c5bb" : "#484848"
                            visible: !occupied
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: pill.hoverProgress = containsMouse ? 1.0 : 0.0
                            onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=\"" + modelData.id + "\"})")
                            onWheel: wheel => { wheel.accepted = false }
                        }
                    }
                }
                }
            }
        }

        Item {
            id: startBtn
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 100

            Canvas {
                id: startBtnCanvas
                anchors.fill: parent
                property real hoverProgress: 0.0
                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHoverProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var slant = 24, w = width, h = height, hp = hoverProgress
                    function drawShape() {
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(w, 0)
                        ctx.lineTo(w - slant, h)
                        ctx.lineTo(0, h)
                        ctx.closePath()
                    }
                    drawShape()
                    var base = ctx.createLinearGradient(0, 0, 0, h)
                    base.addColorStop(0,    "#3d3d3d")
                    base.addColorStop(0.08, "#2a2a2a")
                    base.addColorStop(0.5,  "#303030")
                    base.addColorStop(1.0,  "#3a3a3a")
                    ctx.fillStyle = base; ctx.fill()
                    if (hp > 0) {
                        drawShape()
                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                        teal.addColorStop(0,    "#80e0e0")
                        teal.addColorStop(0.08, "#39c5bb")
                        teal.addColorStop(0.5,  "#2a8a8a")
                        teal.addColorStop(1.0,  "#3a6a6a")
                        ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                    }
                    ctx.save()
                    drawShape()
                    ctx.clip()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                    gloss.addColorStop(0, "rgba(255,255,255," + (0.22 + hp * 0.18) + ")")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss
                    ctx.fillRect(0, 0, w, h * 0.55)
                    ctx.restore()
                    ctx.beginPath()
                    ctx.moveTo(0, 0.5)
                    ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -5
                anchors.horizontalCenterOffset: -8
                visible: startMenu.startIconPath === ""
                text: startMenu.defaultStartIcon
                font.pixelSize: 18
                color: startBtnArea.containsMouse ? "#ffffff" : "#39c5bb"
                Behavior on color { ColorAnimation { duration: 130 } }
            }

            Image {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: -8
                width: 48; height: 48
                visible: startMenu.startIconPath !== ""
                source: startMenu.startIconPath !== "" ? "file://" + startMenu.startIconPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            MouseArea {
                id: startBtnArea
                anchors { left: parent.left; top: parent.top; right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: startBtnCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                onClicked: {
                    var pos = barBg.mapToGlobal(0, barBg.height)
                    startMenu.open(pos.x, pos.y + 6)
                }
            }
        }
    }
}

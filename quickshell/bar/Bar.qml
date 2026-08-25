import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

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
        property bool isNarrow: panel.width < 1500
        property bool isVeryNarrow: panel.width < 1250
        property var preferredPlayer: null
        property string preferredPlayerIdentity: ""
        readonly property string preferredPlayerStatePath: Quickshell.env("HOME") + "/.cache/qs-preferred-player"
        property var activePlayer: {
            var players = Mpris.players.values
            if (preferredPlayer && players.indexOf(preferredPlayer) !== -1) return preferredPlayer
            return players.find(p => p.isPlaying) ?? (players.length > 0 ? players[0] : null)
        }

        function setPreferredPlayer(player) {
            panel.preferredPlayer = player
            panel.preferredPlayerIdentity = player ? player.identity : ""
            savePreferredPlayerProc.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s' \"" + panel.preferredPlayerIdentity + "\" > \"" + panel.preferredPlayerStatePath + "\""]
            savePreferredPlayerProc.running = false
            savePreferredPlayerProc.running = true
        }

        function resolvePreferredPlayer() {
            if (panel.preferredPlayerIdentity === "") return
            var players = Mpris.players.values
            var match = players.find(p => p.identity === panel.preferredPlayerIdentity)
            if (match) panel.preferredPlayer = match
        }

        Component.onCompleted: loadPreferredPlayerProc.running = true

        Process {
            id: loadPreferredPlayerProc
            command: ["cat", panel.preferredPlayerStatePath]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    panel.preferredPlayerIdentity = text.trim()
                    panel.resolvePreferredPlayer()
                }
            }
        }

        Process { id: savePreferredPlayerProc; command: []; running: false }

        Connections {
            target: Mpris.players
            function onValuesChanged() { panel.resolvePreferredPlayer() }
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
            if (controlCenter.sliderActive) return
            var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
            var barBottom = barBg.mapToGlobal(0, barBg.height)
            brightnessOsd.show(wsCenter.x - brightnessOsd.width / 2, barBottom.y + 8)
        }

        property bool batteryAvailable: false
        property int batteryPercent: 100
        property string batteryStatus: ""

        function refreshBattery() {
            batteryProc.running = false
            batteryProc.running = true
        }

        Timer {
            interval: 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshBattery()
        }

        Process {
            id: batteryProc
            command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/uevent 2>/dev/null"]
            onExited: code => { if (code !== 0) panel.batteryAvailable = false }
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "") { panel.batteryAvailable = false; return }
                    var capMatch = text.match(/POWER_SUPPLY_CAPACITY=(\d+)/)
                    var statusMatch = text.match(/POWER_SUPPLY_STATUS=(\w+)/)
                    if (!capMatch) { panel.batteryAvailable = false; return }
                    panel.batteryAvailable = true
                    panel.batteryPercent = parseInt(capMatch[1])
                    panel.batteryStatus = statusMatch ? statusMatch[1] : ""
                }
            }
        }

        function batteryGlyph(percent, status) {
            if (status === "Charging") return "󰂄"
            if (percent >= 95) return "󰁹"
            if (percent >= 80) return "󰂀"
            if (percent >= 60) return "󰁿"
            if (percent >= 40) return "󰁽"
            if (percent >= 20) return "󰁻"
            return "󰁺"
        }

        property real cpuPercent: 0
        property var cpuCorePercents: []
        property real ramPercent: 0
        property real ramUsedGb: 0
        property real ramTotalGb: 0
        property real cpuTempC: -1
        property string uptimeText: ""

        property real gpuPercent: -1
        property real gpuTempC: -1
        property real gpuVramUsedGb: 0
        property real gpuVramTotalGb: 0
        property real gpuVramPercent: 0

        property var prevCpuTotals: ({})

        function refreshPerf() {
            perfProc.running = false
            perfProc.running = true
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshPerf()
        }

        Process {
            id: perfProc
            command: ["bash", "-c",
                "grep '^cpu' /proc/stat; echo '---'; cat /proc/meminfo; echo '---'; cat /proc/uptime; echo '---'; sensors -j 2>/dev/null; echo '---'; " +
                "for d in /sys/class/drm/card*/device; do if grep -q amdgpu \"$d/uevent\" 2>/dev/null; then " +
                "echo \"$(cat $d/gpu_busy_percent 2>/dev/null)\t$(cat $d/mem_info_vram_used 2>/dev/null)\t$(cat $d/mem_info_vram_total 2>/dev/null)\"; break; fi; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var sections = text.split("---\n")
                    if (sections.length < 5) return
                    var cpuLines = sections[0].trim().split("\n")
                    var memText = sections[1]
                    var uptimeText = sections[2].trim()
                    var sensorsText = sections[3]
                    var gpuLine = sections[4].trim()

                    var newTotals = {}
                    var overallPercent = 0
                    var corePercents = []

                    for (var i = 0; i < cpuLines.length; i++) {
                        var parts = cpuLines[i].trim().split(/\s+/)
                        var label = parts[0]
                        var nums = parts.slice(1).map(function(n) { return parseInt(n, 10) || 0 })
                        var idle = nums[3] + nums[4]
                        var total = nums.reduce(function(a, b) { return a + b }, 0)
                        newTotals[label] = { idle: idle, total: total }

                        var prev = panel.prevCpuTotals[label]
                        var pct = 0
                        if (prev) {
                            var totalDelta = total - prev.total
                            var idleDelta = idle - prev.idle
                            pct = totalDelta > 0 ? Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta)) : 0
                        }

                        if (label === "cpu") overallPercent = pct
                        else corePercents.push(pct)
                    }

                    panel.prevCpuTotals = newTotals
                    panel.cpuPercent = overallPercent
                    panel.cpuCorePercents = corePercents

                    var memTotalMatch = memText.match(/MemTotal:\s+(\d+)/)
                    var memAvailMatch = memText.match(/MemAvailable:\s+(\d+)/)
                    if (memTotalMatch && memAvailMatch) {
                        var totalKb = parseInt(memTotalMatch[1], 10)
                        var availKb = parseInt(memAvailMatch[1], 10)
                        var usedKb = totalKb - availKb
                        panel.ramTotalGb = totalKb / 1048576
                        panel.ramUsedGb = usedKb / 1048576
                        panel.ramPercent = totalKb > 0 ? (usedKb / totalKb) * 100 : 0
                    }

                    var upSeconds = parseFloat(uptimeText.split(" ")[0]) || 0
                    var days = Math.floor(upSeconds / 86400)
                    var hours = Math.floor((upSeconds % 86400) / 3600)
                    var mins = Math.floor((upSeconds % 3600) / 60)
                    panel.uptimeText = (days > 0 ? days + "d " : "") + hours + "h " + mins + "m"

                    try {
                        var sensorsData = JSON.parse(sensorsText)
                        var k10 = sensorsData["k10temp-pci-00c3"]
                        if (k10 && k10.Tctl) panel.cpuTempC = k10.Tctl.temp1_input
                        var amdgpu = sensorsData["amdgpu-pci-2d00"]
                        if (amdgpu && amdgpu.edge) panel.gpuTempC = amdgpu.edge.temp1_input
                    } catch (e) {}

                    var gpuParts = gpuLine.split("\t")
                    if (gpuParts.length === 3 && gpuParts[0] !== "") {
                        panel.gpuPercent = parseInt(gpuParts[0], 10) || 0
                        var vramUsed = parseInt(gpuParts[1], 10) || 0
                        var vramTotal = parseInt(gpuParts[2], 10) || 0
                        panel.gpuVramUsedGb = vramUsed / 1073741824
                        panel.gpuVramTotalGb = vramTotal / 1073741824
                        panel.gpuVramPercent = vramTotal > 0 ? (vramUsed / vramTotal) * 100 : 0
                    } else {
                        panel.gpuPercent = -1
                    }
                }
            }
        }

        property bool powerProfilesAvailable: false
        property string powerProfile: ""
        property var powerProfilesList: []

        function refreshPowerProfile() {
            powerProfileGetProc.running = false
            powerProfileGetProc.running = true
        }

        Timer {
            interval: 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: panel.refreshPowerProfile()
        }

        Process {
            id: powerProfileGetProc
            command: ["powerprofilesctl", "list"]
            onExited: code => { if (code !== 0) panel.powerProfilesAvailable = false }
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.split("\n")
                    var profiles = []
                    var active = ""
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]
                        var m = line.match(/^(\*| ) ([A-Za-z0-9_-]+):\s*$/)
                        if (!m) continue
                        profiles.push(m[2])
                        if (m[1] === "*") active = m[2]
                    }
                    if (profiles.length === 0) { panel.powerProfilesAvailable = false; return }
                    panel.powerProfilesAvailable = true
                    panel.powerProfilesList = profiles
                    if (active !== "") panel.powerProfile = active
                }
            }
        }

        function setPowerProfile(name) {
            panel.powerProfile = name
            powerProfileSetProc.command = ["powerprofilesctl", "set", name]
            powerProfileSetProc.running = false
            powerProfileSetProc.running = true
        }

        Process {
            id: powerProfileSetProc
        }

        function powerProfileGlyph(name) {
            if (name === "performance") return "󰓅"
            if (name === "power-saver") return "󰌪"
            return "󰗑"
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
            onTriggered: panel.refreshWeather()
        }

        Timer {
            interval: 10000
            running: true
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
            if (controlCenter.sliderActive || startMenu.audioSliderActive) return
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
        implicitHeight: 56
        color: "transparent"
        exclusiveZone: 52

        TrayMenu {
            id: trayMenu
        }

        MediaPopup {
            id: mediaPopup
            activePlayer: panel.activePlayer
            preferredPlayer: panel.preferredPlayer
            cavaBars: panel.cavaBars
            onPreferredPlayerChanged: panel.setPreferredPlayer(mediaPopup.preferredPlayer)
        }

        ToastWin {
            id: toastWin
        }

        ScreenshotWin {
            id: screenshotWin
            onEditRequested: (path, trig) => {
                screenshotWin.isOpen = false
                screenshotWin.visible = false
                screenshotEditor.open(path, trig)
                screenshotEditor.visible = true
            }
        }

        ScreenshotEditor {
            id: screenshotEditor
        }

        StartMenu {
            id: startMenu
        }

        ControlCenter {
            id: controlCenter
            trackedNotifications: notifServer.trackedNotifications
            notifCount: shellRoot.globalNotifCount
            onNotifCountReset: shellRoot.globalNotifCount = 0
            brightness: panel.brightness
            brightnessAvailable: panel.brightnessAvailable
            onBrightnessMoved: v => panel.setBrightness(v)
        }

        BatteryPopup {
            id: batteryPopup
            percent: panel.batteryPercent
            status: panel.batteryStatus
            profilesAvailable: panel.powerProfilesAvailable
            profiles: panel.powerProfilesList
            activeProfile: panel.powerProfile
            glyphFn: panel.powerProfileGlyph
            onProfileSelected: name => panel.setPowerProfile(name)
        }

        NetworkPopup {
            id: networkPopup
        }

        CalendarPopup {
            id: calendarPopup
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

        PerformancePopup {
            id: performancePopup
            cpuPercent: panel.cpuPercent
            cpuCorePercents: panel.cpuCorePercents
            cpuTempC: panel.cpuTempC
            ramPercent: panel.ramPercent
            ramUsedGb: panel.ramUsedGb
            ramTotalGb: panel.ramTotalGb
            uptimeText: panel.uptimeText
            gpuPercent: panel.gpuPercent
            gpuTempC: panel.gpuTempC
            gpuVramPercent: panel.gpuVramPercent
            gpuVramUsedGb: panel.gpuVramUsedGb
            gpuVramTotalGb: panel.gpuVramTotalGb
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
            height: 52

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
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#8ff5f0" }
                    GradientStop { position: 1.0; color: "#1f8a82" }
                }
            }

            Row {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 14 }
                spacing: 10

                GlowButton {
                    id: networkItem
                    width: 39; height: 34
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: panel.netType === "ethernet" ? "󰈀" : (panel.netType === "wifi" ? "󰤨" : "󰤭")
                        font.pixelSize: 16
                        color: networkItem.hovered ? "#ffffff" : (panel.netConnected ? "#888888" : "#555555")
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    onClicked: {
                        var center = mapToGlobal(width / 2, 0)
                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                        networkPopup.open(center.x - networkPopup.width / 2, barBottom.y + 6)
                    }
                }

                Item {
                    id: quickSettingsItem
                    readonly property int glyphWidth: 39
                    readonly property int glyphCount: 2 + (panel.brightnessAvailable ? 1 : 0)
                    width: glyphWidth * glyphCount
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter

                    PwObjectTracker {
                        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
                    }

                    Canvas {
                        id: quickSettingsCanvas
                        anchors.fill: parent
                        property real hoverProgress: (qsAudioArea.containsMouse || qsBrightnessArea.containsMouse || qsNotifArea.containsMouse) ? 1.0 : 0.0
                        property real mx: 0.5
                        property real my: 0.5
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onMxChanged: requestPaint()
                        onMyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(quickSettingsCanvas, hoverProgress)
                    }

                    function openTab(tab, area) {
                        var center = area.mapToGlobal(area.width / 2, 0)
                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                        controlCenter.activeTab = tab
                        controlCenter.open(center.x - controlCenter.width / 2, barBottom.y + 6)
                    }

                    Row {
                        anchors.fill: parent

                        Item {
                            id: qsAudioZone
                            width: quickSettingsItem.glyphWidth
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "󰝟" : "󰕾"
                                font.pixelSize: 16
                                color: qsAudioArea.containsMouse ? "#ffffff" : "#888888"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            MouseArea {
                                id: qsAudioArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => {
                                    quickSettingsCanvas.mx = Math.max(0, Math.min(1, (parent.x + mouse.x) / quickSettingsItem.width))
                                    quickSettingsCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: quickSettingsItem.openTab("audio", qsAudioArea)
                            }
                        }

                        Item {
                            id: qsBrightnessZone
                            visible: panel.brightnessAvailable
                            width: panel.brightnessAvailable ? quickSettingsItem.glyphWidth : 0
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: "󰃟"
                                font.pixelSize: 16
                                color: qsBrightnessArea.containsMouse ? "#ffffff" : "#888888"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            MouseArea {
                                id: qsBrightnessArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => {
                                    quickSettingsCanvas.mx = Math.max(0, Math.min(1, (parent.x + mouse.x) / quickSettingsItem.width))
                                    quickSettingsCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: quickSettingsItem.openTab("audio", qsBrightnessArea)
                            }
                        }

                        Item {
                            id: qsNotifZone
                            width: quickSettingsItem.glyphWidth
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: "󰂚"
                                font.pixelSize: 16
                                color: qsNotifArea.containsMouse ? "#ffffff" : shellRoot.globalNotifCount > 0 ? "#39c5bb" : "#888888"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            Rectangle {
                                visible: shellRoot.globalNotifCount > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                                width: 8; height: 8; radius: 4
                                color: "#ff4444"
                            }

                            MouseArea {
                                id: qsNotifArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: mouse => {
                                    quickSettingsCanvas.mx = Math.max(0, Math.min(1, (parent.x + mouse.x) / quickSettingsItem.width))
                                    quickSettingsCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: quickSettingsItem.openTab("notifications", qsNotifArea)
                            }
                        }
                    }
                }

                Item {
                    id: batteryItem
                    visible: panel.batteryAvailable
                    width: panel.batteryAvailable ? batteryRow.width + 20 : 0
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Canvas {
                        id: batteryCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        property real mx: 0.5
                        property real my: 0.5
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onMxChanged: requestPaint()
                        onMyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(batteryCanvas, hoverProgress)
                    }

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.batteryGlyph(panel.batteryPercent, panel.batteryStatus)
                            color: panel.batteryStatus === "Charging" ? "#39c5bb" : (panel.batteryPercent <= 15 ? "#ff6b6b" : (batteryMouseArea.containsMouse ? "#ffffff" : "#888888"))
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !panel.isNarrow
                            text: panel.batteryPercent + "%"
                            color: batteryMouseArea.containsMouse ? "#ffffff" : "#999999"
                            font.pixelSize: 11; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    MouseArea {
                        id: batteryMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: batteryCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            batteryCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            batteryCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            batteryPopup.open(center.x - batteryPopup.width / 2, barBottom.y + 6)
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

                Item {
                    id: clockPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: clockColumn.width + 24
                    height: 34

                    Canvas {
                        id: clockPillCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        property real mx: 0.5
                        property real my: 0.5
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onMxChanged: requestPaint()
                        onMyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(clockPillCanvas, hoverProgress, 8)
                    }

                    MouseArea {
                        id: clockMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: clockPillCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            clockPillCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            clockPillCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            calendarPopup.open(center.x - calendarPopup.width / 2, barBottom.y + 6)
                        }
                    }

                    Column {
                        id: clockColumn
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            id: clockText
                            anchors.right: parent.right
                            color: "#d0d0d0"
                            font.pixelSize: 14
                            font.family: "monospace"
                            text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                        }

                        Text {
                            id: dateText
                            visible: !panel.isNarrow
                            anchors.right: parent.right
                            color: "#777777"
                            font.pixelSize: 10
                            font.family: "monospace"
                            text: Qt.formatDateTime(new Date(), "ddd dd MMM")
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
            }

            Item {
                id: perfItem
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 110 }
                visible: !panel.isNarrow
                width: visible ? perfRow.width + 24 : 0
                height: 34

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Canvas {
                    id: perfCanvas
                    anchors.fill: parent
                    property real hoverProgress: 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    onHoverProgressChanged: requestPaint()
                    onMxChanged: requestPaint()
                    onMyChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(perfCanvas, hoverProgress, 6)
                }

                Row {
                    id: perfRow
                    anchors.centerIn: parent
                    spacing: 8

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰻠"
                            color: panel.cpuPercent >= 85 ? "#ff6b6b" : (perfMouseArea.containsMouse ? "#ffffff" : "#999999")
                            font.pixelSize: 13
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(panel.cpuPercent) + "%"
                            color: perfMouseArea.containsMouse ? "#ffffff" : "#999999"
                            font.pixelSize: 12; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍛"
                            color: panel.ramPercent >= 90 ? "#ff6b6b" : (perfMouseArea.containsMouse ? "#ffffff" : "#999999")
                            font.pixelSize: 13
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(panel.ramPercent) + "%"
                            color: perfMouseArea.containsMouse ? "#ffffff" : "#999999"
                            font.pixelSize: 12; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: panel.gpuPercent >= 0

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰢮"
                            color: panel.gpuPercent >= 85 ? "#ff6b6b" : (perfMouseArea.containsMouse ? "#ffffff" : "#999999")
                            font.pixelSize: 13
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(panel.gpuPercent) + "%"
                            color: perfMouseArea.containsMouse ? "#ffffff" : "#999999"
                            font.pixelSize: 12; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }
                }

                MouseArea {
                    id: perfMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: perfCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                    onPositionChanged: mouse => {
                        perfCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                        perfCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                    }
                    onClicked: {
                        var center = mapToGlobal(width / 2, 0)
                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                        performancePopup.open(center.x - performancePopup.width / 2, barBottom.y + 6)
                    }
                }
            }

            Item {
                id: weatherItem
                anchors { left: wsArea.right; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                visible: panel.weatherLoaded && !panel.isNarrow
                width: visible ? weatherRow.width + 24 : 0
                height: 34

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Canvas {
                    id: weatherCanvas
                    anchors.fill: parent
                    property real hoverProgress: 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    onHoverProgressChanged: requestPaint()
                    onMxChanged: requestPaint()
                    onMyChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(weatherCanvas, hoverProgress, 6)
                }

                Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.weatherGlyph(panel.weatherCode)
                        color: weatherMouseArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 16
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
                    onPositionChanged: mouse => {
                        weatherCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                        weatherCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                    }
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
                visible: !panel.isVeryNarrow
                width: visible ? (panel.lastPickedColor !== "" ? colorPickerRow.width + 24 : 38) : 0
                height: 34

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Canvas {
                    id: colorPickerCanvas
                    anchors.fill: parent
                    property real hoverProgress: 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    onHoverProgressChanged: requestPaint()
                    onMxChanged: requestPaint()
                    onMyChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(colorPickerCanvas, hoverProgress, 6)
                }

                Row {
                    id: colorPickerRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰈊"
                        color: colorPickerMouseArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 16
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
                    onPositionChanged: mouse => {
                        colorPickerCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                        colorPickerCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                    }
                    onClicked: panel.pickColor()
                }
            }

            Row {
                anchors { right: wsArea.left; top: parent.top; bottom: parent.bottom }
                spacing: 0
                visible: panel.activePlayer !== null

                GlowButton {
                    id: mediaWidget
                    width: mediaRow.width + 28
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter
                    cut: 7
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    onClicked: {
                        var center = mapToGlobal(width / 2, 0)
                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                        mediaPopup.open(center.x - mediaPopup.width / 2, barBottom.y + 6)
                    }

                    Row {
                        id: mediaRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: "#111111"
                            clip: true
                            border.color: "#3a3a3a"
                            border.width: 1

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
                                font.pixelSize: 13
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
                                color: mediaWidget.hovered ? "#ffffff" : "#d0d0d0"
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }

                            Text {
                                id: mediaArtistText
                                width: Math.min(implicitWidth, parent.maxTextWidth)
                                text: panel.activePlayer ? panel.activePlayer.trackArtist : ""
                                color: mediaWidget.hovered ? "#999999" : "#666666"
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideRight
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                        }

                        Item {
                            id: cavaViewport
                            readonly property int glowPad: 2
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22 + glowPad * 2
                            clip: true
                            visible: width > 0
                            width: (panel.activePlayer !== null && panel.activePlayer.isPlaying) ? cavaRow.implicitWidth + glowPad * 2 : 0
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            opacity: (panel.activePlayer !== null && panel.activePlayer.isPlaying) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Row {
                                id: cavaRow
                                anchors.right: parent.right
                                anchors.rightMargin: cavaViewport.glowPad
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: cavaViewport.glowPad
                                spacing: 1.5

                                Repeater {
                                    model: panel.cavaBars

                                    delegate: Rectangle {
                                        required property var modelData
                                        anchors.bottom: parent.bottom
                                        width: 2
                                        height: Math.max(1.5, (modelData / 100) * 22)
                                        radius: 1
                                        color: "#39c5bb"
                                        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }

                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowColor: "#39c5bb"
                                            shadowBlur: 0.8
                                            shadowOpacity: 0.85
                                            shadowHorizontalOffset: 0
                                            shadowVerticalOffset: 0
                                            blurMax: 24
                                            autoPaddingEnabled: true
                                        }
                                    }
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

                        function toplevelAppId(t) {
                            if (t.wayland && t.wayland.appId !== "") return t.wayland.appId
                            if (t.lastIpcObject) return t.lastIpcObject["class"] || ""
                            return ""
                        }

                        property var appIcons: {
                            var counts = ({})
                            var order = []
                            for (var i = 0; i < toplevels.length; i++) {
                                var id = toplevelAppId(toplevels[i])
                                if (id === "") continue
                                if (counts[id] === undefined) { counts[id] = 0; order.push(id) }
                                counts[id]++
                            }
                            var icons = []
                            for (var j = 0; j < order.length; j++) {
                                var appId = order[j]
                                var entry = DesktopEntries.heuristicLookup(appId)
                                if (entry && entry.icon !== "") icons.push({ icon: entry.icon, count: counts[appId] })
                            }
                            return icons
                        }

                        width: occupied ? Math.max(38, appIconsRow.implicitWidth + 22) : (modelData.active ? 28 : 14)
                        height: 32

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        SequentialAnimation {
                            running: modelData.active
                            loops: Animation.Infinite
                            NumberAnimation { target: pill; property: "pulse"; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { target: pill; property: "pulse"; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                        }

                        Canvas {
                            id: pill
                            anchors.fill: parent
                            visible: parent.occupied

                            property bool active: modelData.active
                            property real activeProgress: active ? 1.0 : 0.0
                            Behavior on activeProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            property real hoverProgress: 0.0
                            property real mx: 0.5
                            property real my: 0.5
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            property real pulse: 0.0
                            onActiveProgressChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()
                            onHoverProgressChanged: requestPaint()
                            onMxChanged: requestPaint()
                            onMyChanged: requestPaint()
                            onPulseChanged: requestPaint()

                            onPaint: DivaPaint.paintWsPill(pill, activeProgress, hoverProgress, pulse)
                        }

                        Row {
                            id: appIconsRow
                            anchors.centerIn: parent
                            spacing: 7
                            visible: occupied && appIcons.length > 0

                            Repeater {
                                model: appIcons
                                delegate: Item {
                                    required property var modelData
                                    width: 18
                                    height: 18

                                    IconImage {
                                        anchors.fill: parent
                                        mipmap: true
                                        source: "image://icon/" + modelData.icon
                                    }

                                    Rectangle {
                                        visible: modelData.count > 1
                                        width: countLabel.implicitWidth + 6
                                        height: 11
                                        radius: 5.5
                                        color: "#1a1a1a"
                                        border.color: "#484848"
                                        border.width: 1
                                        anchors { right: parent.right; bottom: parent.bottom; rightMargin: -4; bottomMargin: -4 }

                                        Text {
                                            id: countLabel
                                            anchors.centerIn: parent
                                            text: modelData.count
                                            color: "#e0e0e0"
                                            font.pixelSize: 8
                                            font.family: "monospace"
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: wsDot
                            anchors.centerIn: parent
                            width: modelData.active ? 8 : 5
                            height: modelData.active ? 8 : 5
                            radius: height / 2
                            color: modelData.active ? "#39c5bb" : (pill.hoverProgress > 0 ? "#7a7a7a" : "#484848")
                            visible: !occupied
                            Behavior on color { ColorAnimation { duration: 130 } }

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: wsDot.color
                                shadowBlur: modelData.active ? 0.7 : 0.5
                                shadowOpacity: modelData.active ? 0.9 : (0.35 + pill.hoverProgress * 0.25)
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                                blurMax: modelData.active ? 20 : 12
                                autoPaddingEnabled: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: pill.hoverProgress = containsMouse ? 1.0 : 0.0
                            onPositionChanged: mouse => {
                                pill.mx = Math.max(0, Math.min(1, mouse.x / width))
                                pill.my = Math.max(0, Math.min(1, mouse.y / height))
                            }
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
                property real mx: 0.5
                property real my: 0.5
                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                onHoverProgressChanged: requestPaint()
                onMxChanged: requestPaint()
                onMyChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: DivaPaint.paintFacetSlant(startBtnCanvas, hoverProgress, 24)
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
                onPositionChanged: mouse => {
                    startBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                    startBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                }
                onClicked: {
                    var pos = barBg.mapToGlobal(0, barBg.height)
                    startMenu.open(pos.x, pos.y + 6)
                }
            }
        }

    }
}

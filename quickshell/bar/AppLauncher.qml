import QtQuick
import Quickshell
import Quickshell.Io

Window {
    id: launcherWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-launcher"
    color: "transparent"
    width: 520
    height: 440
    visible: false

    property string searchText: ""
    property string usagePath: Quickshell.env("HOME") + "/.cache/qs-launcher-usage.json"
    property var usageStats: ({})

    property var allApps: {
        try {
            return DesktopEntries.applications.values
                .filter(e => e && !e.noDisplay && e.name !== "")
                .sort((a, b) => a.name.localeCompare(b.name))
        } catch (_) { return [] }
    }

    function fuzzyScore(text, query) {
        if (query === "") return 0
        text = text.toLowerCase()
        query = query.toLowerCase()
        var ti = 0, qi = 0, consecutive = 0, score = 0, firstMatch = -1
        while (ti < text.length && qi < query.length) {
            if (text[ti] === query[qi]) {
                if (firstMatch === -1) firstMatch = ti
                consecutive++
                score += 1 + consecutive * 2
                if (ti === 0 || text[ti - 1] === " " || text[ti - 1] === "-") score += 8
                qi++
            } else {
                consecutive = 0
            }
            ti++
        }
        if (qi < query.length) return -1
        score += Math.max(0, 10 - firstMatch)
        score -= text.length * 0.05
        return score
    }

    function frecencyScore(app) {
        var stats = launcherWin.usageStats[app.id]
        if (!stats) return 0
        var ageHours = (Date.now() - stats.lastUsed) / 3600000
        var recency = Math.max(0, 50 - ageHours)
        return stats.count * 4 + recency
    }

    property var filteredApps: {
        if (searchText === "") {
            return allApps.slice().sort((a, b) => {
                var d = launcherWin.frecencyScore(b) - launcherWin.frecencyScore(a)
                return d !== 0 ? d : a.name.localeCompare(b.name)
            })
        }
        var ranked = []
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i]
            var nameScore = launcherWin.fuzzyScore(app.name, searchText)
            var genericScore = app.genericName ? launcherWin.fuzzyScore(app.genericName, searchText) * 0.7 : -1
            var best = Math.max(nameScore, genericScore)
            if (best < 0) continue
            ranked.push({ app: app, score: best + launcherWin.frecencyScore(app) * 0.3 })
        }
        ranked.sort((a, b) => b.score - a.score)
        return ranked.map(r => r.app)
    }

    function toggleLauncher() {
        if (launcherWin.visible) closeLauncher()
        else openLauncher()
    }

    function openLauncher() {
        visible = true
        launcherWin.raise()
        launcherWin.requestActivate()
        launcherSearch.forceActiveFocus()
    }

    function closeLauncher() {
        launcherSearch.text = ""
        launcherWin.visible = false
    }

    function launchApp(app) {
        app.execute()
        recordLaunch(app)
        closeLauncher()
    }

    function recordLaunch(app) {
        var key = app.id || app.name
        var stats = {}
        for (var k in launcherWin.usageStats) stats[k] = launcherWin.usageStats[k]
        var existing = stats[key] || { count: 0, lastUsed: 0 }
        stats[key] = { count: existing.count + 1, lastUsed: Date.now() }
        launcherWin.usageStats = stats
        saveUsageProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + launcherWin.usagePath + "\" <<'USAGE_EOF'\n" + JSON.stringify(stats) + "\nUSAGE_EOF\n"]
        saveUsageProc.running = false
        saveUsageProc.running = true
    }

    Component.onCompleted: { loadUsageProc.running = true }

    Process {
        id: loadUsageProc
        command: ["cat", launcherWin.usagePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try { launcherWin.usageStats = JSON.parse(text) } catch (_) { launcherWin.usageStats = {} }
            }
        }
    }

    Process {
        id: saveUsageProc
        command: ["true"]
        running: false
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherWin.toggleLauncher() }
        function show(): void { launcherWin.openLauncher() }
        function hide(): void { launcherWin.closeLauncher() }
    }

    Rectangle {
        id: launcherRect
        anchors.fill: parent
        color: "#1a1a1a"

        Column {
            anchors.fill: parent

            Item {
                width: parent.width
                height: 56

                Item {
                    id: searchBox
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }

                    Canvas {
                        id: searchBoxCanvas
                        anchors.fill: parent
                        property real focusProgress: launcherSearch.activeFocus ? 1.0 : 0.0
                        Behavior on focusProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onFocusProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 8, w = width, h = height, fp = focusProgress
                            function drawShape() {
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                            }
                            drawShape()
                            ctx.fillStyle = "#242424"; ctx.fill()
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                            ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.05 + fp * 0.04) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = fp > 0.5 ? "#c0f4f4" : "#3a3a3a"; ctx.lineWidth = 1; ctx.stroke()
                            drawShape()
                            ctx.strokeStyle = fp > 0 ? Qt.rgba(0.224, 0.773, 0.733, fp) : "#2e2e2e"
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        text: "󰍉"
                        color: launcherSearch.activeFocus ? "#39c5bb" : "#444444"
                        font.pixelSize: 16
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    TextInput {
                        id: launcherSearch
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 36; rightMargin: 12 }
                        color: "#e0e0e0"
                        font.pixelSize: 14; font.family: "monospace"
                        selectByMouse: true
                        onTextChanged: launcherWin.searchText = text
                        Keys.onEscapePressed: launcherWin.closeLauncher()
                        Keys.onReturnPressed: {
                            var idx = launcherAppList.currentIndex >= 0 ? launcherAppList.currentIndex : 0
                            if (launcherWin.filteredApps.length > 0)
                                launcherWin.launchApp(launcherWin.filteredApps[idx])
                        }
                        Keys.onUpPressed: launcherAppList.decrementCurrentIndex()
                        Keys.onDownPressed: launcherAppList.incrementCurrentIndex()
                    }
                }
            }

            Item {
                width: parent.width
                height: 22
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: launcherWin.searchText === "" ? "all apps" : ("results (" + launcherWin.filteredApps.length + ")")
                    color: "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            ListView {
                id: launcherAppList
                width: parent.width
                height: parent.height - 56 - 22
                clip: true
                model: launcherWin.filteredApps
                currentIndex: -1

                Connections {
                    target: launcherWin
                    function onFilteredAppsChanged() {
                        launcherAppList.currentIndex = launcherWin.filteredApps.length > 0 ? 0 : -1
                    }
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 42

                    Rectangle {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 8 }
                        color: appRowArea.containsMouse || launcherAppList.currentIndex === index ? "#242424" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Rectangle {
                            width: 2; height: parent.height * 0.6
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            color: "#39c5bb"
                            opacity: appRowArea.containsMouse || launcherAppList.currentIndex === index ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 80 } }
                        }

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                            spacing: 12

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: modelData.name
                                    color: appRowArea.containsMouse || launcherAppList.currentIndex === index ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 13; font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                Text {
                                    text: modelData.genericName ?? ""
                                    color: "#555555"
                                    font.pixelSize: 10; font.family: "monospace"
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            id: appRowArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) launcherAppList.currentIndex = index
                            onClicked: launcherWin.launchApp(modelData)
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: launcherWin.filteredApps.length === 0
                text: "no apps found"
                color: "#444444"
                font.pixelSize: 12; font.family: "monospace"
                topPadding: 20
            }
        }
    }
}

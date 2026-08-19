import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

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

    readonly property var kanadeEntry: ({
        id: "kanade",
        name: "Kanade",
        genericName: "music library & DAP sync",
        icon: "multimedia-player",
        isCustom: true,
        execute: function() { kanadeToggleProc.running = false; kanadeToggleProc.running = true }
    })

    readonly property var githubEntry: ({
        id: "github",
        name: "GitHub",
        genericName: "look at your github stuff",
        icon: "xsi-github-symbolic",
        isCustom: true,
        execute: function() { githubToggleProc.running = false; githubToggleProc.running = true }
    })

    readonly property var reposEntry: ({
        id: "repos",
        name: "Repos",
        genericName: "manage repos & submodules",
        icon: "xsi-git-symbolic",
        isCustom: true,
        execute: function() { reposToggleProc.running = false; reposToggleProc.running = true }
    })

    readonly property var customEntries: [launcherWin.kanadeEntry, launcherWin.githubEntry, launcherWin.reposEntry]

    property var allApps: {
        try {
            return DesktopEntries.applications.values
                .filter(e => e && !e.noDisplay && e.name !== "")
                .sort((a, b) => a.name.localeCompare(b.name))
        } catch (_) { return [] }
    }

    readonly property bool commandMode: searchText.startsWith(">")
    readonly property string commandQuery: commandMode ? searchText.slice(1).trimStart() : ""

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
        if (commandMode) {
            if (commandQuery === "") return customEntries.slice()
            var rankedCmd = []
            for (var c = 0; c < customEntries.length; c++) {
                var centry = customEntries[c]
                var cScore = launcherWin.fuzzyScore(centry.name, commandQuery)
                if (cScore < 0) continue
                rankedCmd.push({ app: centry, score: cScore })
            }
            rankedCmd.sort((a, b) => b.score - a.score)
            return rankedCmd.map(r => r.app)
        }

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

    function appKey(app) { return app.id || app.name }

    property var filteredRank: {
        var rank = {}
        var apps = launcherWin.filteredApps
        for (var i = 0; i < apps.length; i++) rank[launcherWin.appKey(apps[i])] = i
        return rank
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

    Process {
        id: kanadeToggleProc
        command: ["quickshell", "ipc", "call", "kanade", "toggle"]
        running: false
    }

    Process {
        id: githubToggleProc
        command: ["quickshell", "ipc", "call", "github", "toggle"]
        running: false
    }

    Process {
        id: reposToggleProc
        command: ["quickshell", "ipc", "call", "repos", "toggle"]
        running: false
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherWin.toggleLauncher() }
        function show(): void { launcherWin.openLauncher() }
        function hide(): void { launcherWin.closeLauncher() }
    }

    PanelBackground {
        id: launcherRect
        anchors.fill: parent

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
                            var w = width, h = height, fp = focusProgress, cut = 10
                            ctx.clearRect(0, 0, w, h)

                            function drawShape() {
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                            }

                            drawShape()
                            var base = ctx.createLinearGradient(0, 0, 0, h)
                            base.addColorStop(0, "#242424"); base.addColorStop(0.5, "#1c1c1c"); base.addColorStop(1.0, "#181818")
                            ctx.fillStyle = base; ctx.fill()

                            if (fp > 0) {
                                drawShape()
                                ctx.save()
                                ctx.clip()
                                ctx.lineWidth = 6
                                ctx.strokeStyle = "rgba(150,245,245," + (fp * 0.35) + ")"
                                ctx.stroke()
                                ctx.restore()
                            }

                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                            ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.05 + fp * 0.03) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()

                            drawShape()
                            ctx.strokeStyle = fp > 0.5 ? "#c0f4f4" : "#3a3a3a"
                            ctx.lineWidth = 1
                            ctx.stroke()

                            if (fp > 0) {
                                drawShape()
                                ctx.strokeStyle = "rgba(150,245,245," + (fp * 0.9) + ")"
                                ctx.lineWidth = 1.4
                                ctx.stroke()
                            }
                        }
                    }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                        text: "󰍉"
                        color: launcherSearch.activeFocus ? "#e0fbfb" : "#666666"
                        font.pixelSize: 16
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    TextInput {
                        id: launcherSearch
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 38; rightMargin: 32 }
                        color: "#f0f0f0"
                        font.pixelSize: 14; font.family: "monospace"
                        selectByMouse: true
                        onTextChanged: launcherWin.searchText = text
                        Keys.onEscapePressed: launcherWin.closeLauncher()
                        Keys.onReturnPressed: {
                            var idx = launcherAppList.currentIndex >= 0 ? launcherAppList.currentIndex : 0
                            if (launcherWin.filteredApps.length > 0)
                                launcherWin.launchApp(launcherWin.filteredApps[idx])
                        }
                        Keys.onUpPressed: launcherAppList.currentIndex = Math.max(0, launcherAppList.currentIndex - 1)
                        Keys.onDownPressed: launcherAppList.currentIndex = Math.min(launcherWin.filteredApps.length - 1, launcherAppList.currentIndex + 1)
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                        visible: launcherSearch.text !== ""
                        text: "󰅖"
                        font.pixelSize: 13
                        color: clearArea.containsMouse ? "#e0fbfb" : "#666666"
                        Behavior on color { ColorAnimation { duration: 130 } }

                        MouseArea {
                            id: clearArea
                            anchors.centerIn: parent
                            width: 24; height: 24
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { launcherSearch.text = ""; launcherSearch.forceActiveFocus() }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 22
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: launcherWin.commandMode
                        ? "commands (" + launcherWin.filteredApps.length + ")"
                        : (launcherWin.searchText === "" ? "all apps" : ("results (" + launcherWin.filteredApps.length + ")"))
                    color: launcherWin.commandMode ? "#39c5bb" : "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
            }

            Flickable {
                id: launcherAppList
                width: parent.width
                height: parent.height - 56 - 22
                clip: true
                contentHeight: launcherWin.filteredApps.length * 46
                boundsBehavior: Flickable.StopAtBounds

                property int currentIndex: -1

                Connections {
                    target: launcherWin
                    function onFilteredAppsChanged() {
                        launcherAppList.currentIndex = launcherWin.filteredApps.length > 0 ? 0 : -1
                    }
                }

                Connections {
                    target: launcherAppList
                    function onCurrentIndexChanged() {
                        var y = launcherAppList.currentIndex * 46
                        if (y < launcherAppList.contentY) launcherAppList.contentY = y
                        else if (y + 46 > launcherAppList.contentY + launcherAppList.height)
                            launcherAppList.contentY = y + 46 - launcherAppList.height
                    }
                }

                Repeater {
                    id: appRepeater
                    model: launcherWin.allApps.concat(launcherWin.customEntries)

                    delegate: Item {
                        id: appRow
                        required property var modelData
                        property int rank: launcherWin.filteredRank[launcherWin.appKey(modelData)] ?? -1
                        property bool selected: appRowArea.containsMouse || launcherAppList.currentIndex === rank
                        width: launcherAppList.width
                        height: 46
                        y: rank >= 0 ? rank * 46 : -46
                        visible: opacity > 0
                        opacity: rank >= 0 ? 1.0 : 0.0
                        Behavior on y { enabled: rank >= 0; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Canvas {
                            id: rowCanvas
                            anchors { fill: parent; leftMargin: 6; rightMargin: 10; topMargin: 2; bottomMargin: 2 }
                            property real hoverProgress: appRow.selected ? 1.0 : 0.0
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
                            onPaint: DivaPaint.paintFacetPill(rowCanvas, hoverProgress, 8, DivaPaint.ACCENT_TEAL)
                        }

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
                            spacing: 12

                            Rectangle {
                                id: iconTile
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30; height: 30
                                radius: 4
                                color: "#1c1c1c"
                                border.color: appRow.modelData.isCustom ? "#39c5bb" : (appRow.selected ? "#3a6a6a" : "#333333")
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "image://icon/" + (appRow.modelData.icon || "application-x-executable")
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: (appRow.modelData.isCustom ? "> " : "") + appRow.modelData.name
                                    color: appRow.modelData.isCustom ? (appRow.selected ? "#ffffff" : "#c0f4f4") : (appRow.selected ? "#ffffff" : "#cccccc")
                                    font.pixelSize: 13; font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                Text {
                                    text: appRow.modelData.genericName ?? ""
                                    color: appRow.selected ? "#b8d8d8" : "#8a8a8a"
                                    font.pixelSize: 11; font.family: "monospace"
                                    visible: text !== ""
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                            }
                        }

                        MouseArea {
                            id: appRowArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse) launcherAppList.currentIndex = appRow.rank
                            }
                            onPositionChanged: mouse => {
                                rowCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                rowCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                            }
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

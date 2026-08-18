import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../DivaPaint.js" as DivaPaint

Window {
    id: kanadeWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "kanade"
    color: "transparent"
    width: 980
    height: 660
    visible: false

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string mediaUser: Quickshell.env("USER")
    readonly property string rootsPath: kanadeWin.homeDir + "/.cache/kanade-roots.json"
    readonly property string translationsPath: kanadeWin.homeDir + "/.cache/kanade-translations.json"
    readonly property string translateAllStatePath: kanadeWin.homeDir + "/.cache/kanade-translate-all"
    readonly property string coverCacheDir: kanadeWin.homeDir + "/.cache/kanade-covers"
    readonly property var audioExts: ["mp3", "flac", "ogg", "wav", "m4a", "opus"]

    property bool translateAll: false
    function setTranslateAll(on) {
        kanadeWin.translateAll = on
        saveTranslateAllProc.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s' \"" + (on ? "1" : "0") + "\" > \"" + kanadeWin.translateAllStatePath + "\""]
        saveTranslateAllProc.running = false
        saveTranslateAllProc.running = true
    }

    property var selectedTrack: null
    property string selectedCoverPath: ""
    property bool selectedCoverMissing: false

    function hashPath(path) {
        var h = 0
        for (var i = 0; i < path.length; i++) {
            h = ((h << 5) - h + path.charCodeAt(i)) | 0
        }
        return (h >>> 0).toString(16)
    }

    function selectTrack(t) {
        kanadeWin.selectedTrack = t
        kanadeWin.selectedCoverMissing = false
        kanadeWin.selectedCoverPath = ""
        var coverPath = kanadeWin.coverCacheDir + "/" + kanadeWin.hashPath(t.path) + ".jpg"
        extractCoverProc.pendingCoverPath = coverPath
        extractCoverProc.command = ["bash", "-c",
            "mkdir -p \"" + kanadeWin.coverCacheDir + "\" && " +
            "[ -f \"" + coverPath + "\" ] || ffmpeg -y -v quiet -i \"" + t.path.replace(/"/g, "\\\"") + "\" -an -vcodec copy -update 1 \"" + coverPath + "\""]
        extractCoverProc.running = false
        extractCoverProc.running = true
    }

    function closeTrackDetails() {
        kanadeWin.selectedTrack = null
    }

    property string section: "library"

    property var libraryRoots: []
    property var tracks: []
    property bool scanning: false
    property string scanError: ""

    property var devices: []
    property string selectedDevicePath: ""
    property bool devicesRefreshing: false

    property bool syncing: false
    property int syncTotal: 0
    property int syncDone: 0
    property string syncError: ""
    property string syncStatusText: ""

    property var translations: ({})
    property var translating: ({})
    property var translateQueue: []
    property bool translateBusy: false

    function needsTranslation(text) {
        return /[^\x00-\x7F]/.test(text)
    }

    function translate(text) {
        if (kanadeWin.translations[text] !== undefined || kanadeWin.translating[text]) return
        var t = {}
        for (var k in kanadeWin.translating) t[k] = kanadeWin.translating[k]
        t[text] = true
        kanadeWin.translating = t
        kanadeWin.translateQueue = kanadeWin.translateQueue.concat([text])
        kanadeWin.pumpTranslateQueue()
    }

    function pumpTranslateQueue() {
        if (kanadeWin.translateBusy || kanadeWin.translateQueue.length === 0) return
        kanadeWin.translateBusy = true
        var text = kanadeWin.translateQueue[0]
        kanadeWin.translateQueue = kanadeWin.translateQueue.slice(1)
        translateProc.pendingText = text
        translateProc.command = ["trans", "-no-ansi", "-show-original-phonetics", "Y", ":en", text]
        translateProc.running = false
        translateProc.running = true
    }

    function saveTranslations() {
        saveTranslationsProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + kanadeWin.translationsPath + "\" <<'TR_EOF'\n" + JSON.stringify(kanadeWin.translations) + "\nTR_EOF\n"]
        saveTranslationsProc.running = false
        saveTranslationsProc.running = true
    }

    function tag(t, key) {
        if (!t.tags) return ""
        return t.tags[key] || t.tags[key.toUpperCase()] || ""
    }

    function trackArtist(t) { return kanadeWin.tag(t, "artist") || "Unknown Artist" }
    function trackAlbum(t) { return kanadeWin.tag(t, "album") || "Unknown Album" }
    function trackTitle(t) {
        var v = kanadeWin.tag(t, "title")
        if (v) return v
        var parts = t.path.split("/")
        return parts[parts.length - 1].replace(/\.[^.]+$/, "")
    }
    function trackNumber(t) {
        var v = kanadeWin.tag(t, "track")
        var n = parseInt(String(v).split("/")[0], 10)
        return isNaN(n) ? 0 : n
    }
    function formatDuration(sec) {
        var s = Math.max(0, Math.round(parseFloat(sec) || 0))
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    function addRoot(path) {
        if (!path || kanadeWin.libraryRoots.indexOf(path) !== -1) return
        kanadeWin.libraryRoots = kanadeWin.libraryRoots.concat([path])
        kanadeWin.saveRoots()
    }
    function removeRoot(path) {
        kanadeWin.libraryRoots = kanadeWin.libraryRoots.filter(function(p) { return p !== path })
        kanadeWin.saveRoots()
    }
    function saveRoots() {
        saveRootsProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + kanadeWin.rootsPath + "\" <<'ROOTS_EOF'\n" + JSON.stringify(kanadeWin.libraryRoots) + "\nROOTS_EOF\n"]
        saveRootsProc.running = false
        saveRootsProc.running = true
    }

    function rescan() {
        if (kanadeWin.scanning || kanadeWin.libraryRoots.length === 0) return
        kanadeWin.scanning = true
        kanadeWin.scanError = ""
        var findExpr = kanadeWin.audioExts.map(function(e) { return "-iname '*." + e + "'" }).join(" -o ")
        var rootsQuoted = kanadeWin.libraryRoots.map(function(r) { return "\"" + r + "\"" }).join(" ")
        var script =
            "find " + rootsQuoted + " -type f \\( " + findExpr + " \\) -print0 2>/dev/null | " +
            "while IFS= read -r -d '' f; do " +
            "ffprobe -v quiet -print_format json -show_entries format=duration:format_tags=artist,album,title,track,genre:stream_tags=artist,album,title,track,genre -select_streams a \"$f\" 2>/dev/null | " +
            "jq -c --arg path \"$f\" '{path: $path, duration: (.format.duration // \"0\"), tags: ((.streams[0].tags // {}) + (.format.tags // {}))}'; " +
            "done | jq -sc '.'"
        scanProc.command = ["bash", "-c", script]
        scanProc.running = false
        scanProc.running = true
    }

    function refreshDevices() {
        kanadeWin.devicesRefreshing = true
        devicesProc.running = false
        devicesProc.running = true
    }

    function syncToDevice() {
        if (kanadeWin.syncing || kanadeWin.selectedDevicePath === "" || kanadeWin.tracks.length === 0) return
        kanadeWin.syncing = true
        kanadeWin.syncError = ""
        kanadeWin.syncDone = 0
        kanadeWin.syncTotal = kanadeWin.tracks.length
        kanadeWin.syncStatusText = "preparing..."

        var destRoot = kanadeWin.selectedDevicePath + "/Music"
        var lines = ["set -uo pipefail", "mkdir -p \"" + destRoot + "\"", "total=" + kanadeWin.syncTotal, "n=0"]
        for (var i = 0; i < kanadeWin.tracks.length; i++) {
            var t = kanadeWin.tracks[i]
            var artist = kanadeWin.trackArtist(t).replace(/[\/\x00]/g, "_")
            var album = kanadeWin.trackAlbum(t).replace(/[\/\x00]/g, "_")
            var title = kanadeWin.trackTitle(t).replace(/[\/\x00]/g, "_")
            var num = kanadeWin.trackNumber(t)
            var ext = t.path.split(".").pop()
            var numPrefix = num > 0 ? (num < 10 ? "0" + num : String(num)) + " - " : ""
            var destDir = destRoot + "/" + artist + "/" + album
            var destFile = destDir + "/" + numPrefix + title + "." + ext
            lines.push("mkdir -p \"" + destDir.replace(/"/g, "\\\"") + "\"")
            lines.push("cp -n \"" + t.path.replace(/"/g, "\\\"") + "\" \"" + destFile.replace(/"/g, "\\\"") + "\" 2>/dev/null")
            lines.push("n=$((n+1)); echo \"PROGRESS $n $total\"")
        }
        lines.push("echo DONE")

        syncProc.command = ["bash", "-c", lines.join("\n")]
        syncProc.running = false
        syncProc.running = true
    }

    Component.onCompleted: {
        loadRootsProc.running = true
        loadTranslationsProc.running = true
        loadTranslateAllProc.running = true
        kanadeWin.refreshDevices()
    }

    onVisibleChanged: {
        if (visible) {
            floatProc.running = false
            floatProc.running = true
            kanadeWin.refreshDevices()
        }
    }

    Process {
        id: floatProc
        command: ["hyprctl", "dispatch", "setfloating", "title:kanade"]
    }

    Process {
        id: loadRootsProc
        command: ["cat", kanadeWin.rootsPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    kanadeWin.libraryRoots = Array.isArray(parsed) ? parsed : []
                } catch (_) {
                    kanadeWin.libraryRoots = [kanadeWin.homeDir + "/Music"]
                }
                if (kanadeWin.libraryRoots.length > 0) kanadeWin.rescan()
            }
        }
    }

    Process {
        id: saveRootsProc
        command: ["true"]
        running: false
    }

    Process {
        id: scanProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                kanadeWin.scanning = false
                try {
                    var parsed = JSON.parse(text)
                    kanadeWin.tracks = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    kanadeWin.scanError = "scan failed to parse results"
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            kanadeWin.scanning = false
            if (code !== 0 && kanadeWin.tracks.length === 0) kanadeWin.scanError = "scan failed (exit " + code + ")"
        }
    }

    Process {
        id: devicesProc
        command: ["bash", "-c", "for d in \"/run/media/" + kanadeWin.mediaUser + "\"/*; do [ -d \"$d\" ] && df -B1 --output=avail,size \"$d\" 2>/dev/null | tail -1 | awk -v n=\"$d\" '{print n\"\\t\"$1\"\\t\"$2}'; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                kanadeWin.devicesRefreshing = false
                var list = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line === "") continue
                    var parts = line.split("\t")
                    if (parts.length !== 3) continue
                    var p = parts[0]
                    list.push({ path: p, name: p.split("/").pop(), avail: parseInt(parts[1], 10) || 0, size: parseInt(parts[2], 10) || 0 })
                }
                kanadeWin.devices = list
                if (kanadeWin.selectedDevicePath !== "" && !list.some(function(d) { return d.path === kanadeWin.selectedDevicePath })) {
                    kanadeWin.selectedDevicePath = ""
                }
            }
        }
    }

    Process {
        id: extractCoverProc
        property string pendingCoverPath: ""
        command: ["true"]
        running: false
        onExited: code => {
            checkCoverProc.pendingCoverPath = extractCoverProc.pendingCoverPath
            checkCoverProc.command = ["test", "-s", extractCoverProc.pendingCoverPath]
            checkCoverProc.running = false
            checkCoverProc.running = true
        }
    }

    Process {
        id: checkCoverProc
        property string pendingCoverPath: ""
        command: ["true"]
        running: false
        onExited: code => {
            var stillCurrent = kanadeWin.selectedTrack && (kanadeWin.coverCacheDir + "/" + kanadeWin.hashPath(kanadeWin.selectedTrack.path) + ".jpg") === checkCoverProc.pendingCoverPath
            if (!stillCurrent) return
            if (code === 0) {
                kanadeWin.selectedCoverMissing = false
                kanadeWin.selectedCoverPath = checkCoverProc.pendingCoverPath
            } else {
                kanadeWin.selectedCoverMissing = true
                kanadeWin.selectedCoverPath = ""
            }
        }
    }

    Process {
        id: translateProc
        property string pendingText: ""
        property string collectedOutput: ""
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { translateProc.collectedOutput = text }
        }
        onExited: code => {
            var key = translateProc.pendingText
            var lines = translateProc.collectedOutput.split("\n")
            var romaji = lines.length > 1 ? lines[1].trim().replace(/^\(|\)$/g, "") : ""
            var en = lines.length > 3 ? lines[3].trim() : ""
            var ok = code === 0 && en !== ""
            var tr = {}
            for (var k in kanadeWin.translations) tr[k] = kanadeWin.translations[k]
            tr[key] = ok ? { romaji: romaji, en: en } : { romaji: "", en: "?" }
            kanadeWin.translations = tr
            var tg = {}
            for (var k2 in kanadeWin.translating) if (k2 !== key) tg[k2] = kanadeWin.translating[k2]
            kanadeWin.translating = tg
            kanadeWin.translateBusy = false
            if (ok) kanadeWin.saveTranslations()
            kanadeWin.pumpTranslateQueue()
        }
    }

    Process {
        id: loadTranslationsProc
        command: ["cat", kanadeWin.translationsPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    kanadeWin.translations = parsed && typeof parsed === "object" ? parsed : {}
                } catch (_) {
                    kanadeWin.translations = {}
                }
            }
        }
    }

    Process {
        id: saveTranslationsProc
        command: ["true"]
        running: false
    }

    Process {
        id: loadTranslateAllProc
        command: ["cat", kanadeWin.translateAllStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { kanadeWin.translateAll = text.trim() === "1" }
        }
    }

    Process {
        id: saveTranslateAllProc
        command: ["true"]
        running: false
    }

    Process {
        id: syncProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.indexOf("PROGRESS") === 0) {
                    var parts = line.split(" ")
                    kanadeWin.syncDone = parseInt(parts[1], 10) || 0
                    kanadeWin.syncStatusText = kanadeWin.syncDone + " / " + kanadeWin.syncTotal
                } else if (line === "DONE") {
                    kanadeWin.syncStatusText = "sync complete"
                }
            }
        }
        onExited: code => {
            kanadeWin.syncing = false
            if (code !== 0) kanadeWin.syncError = "sync failed (exit " + code + ")"
            kanadeWin.refreshDevices()
        }
    }

    PanelBackground {
        anchors.fill: parent
        showBorder: false

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "kanade"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 90 }
                text: kanadeWin.tracks.length + " tracks in library"
                color: "#555555"
                font.pixelSize: 10; font.family: "monospace"
            }

            Item {
                id: closeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 28; height: 22

                Canvas {
                    id: closeBtnCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onMxChanged: requestPaint()
                    onMyChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(closeBtnCanvas, closeBtnCanvas.hp, 4, DivaPaint.ACCENT_RED)
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
                    onPositionChanged: mouse => {
                        closeBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                        closeBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                    }
                    onClicked: kanadeWin.visible = false
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2a2a2a"
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) kanadeWin.startSystemMove()
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
                        property bool active: kanadeWin.section === target
                        width: parent.width
                        height: 38

                        Item {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 2; bottomMargin: 2 }

                            Canvas {
                                id: navCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: navItem
                                    function onActiveChanged() { navCanvas.requestPaint() }
                                }
                                onPaint: DivaPaint.paintFacetPill(navCanvas, navItem.active ? 1.0 : navCanvas.hp, 6)
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
                                onPositionChanged: mouse => {
                                    navCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    navCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: kanadeWin.section = navItem.target
                            }
                        }
                    }

                    NavItem { sym: "󰎈"; label: "library"; target: "library" }
                    NavItem { sym: "󰄝"; label: "device"; target: "device" }
                    NavItem { sym: "󰉪"; label: "folders"; target: "folders" }
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height

                LibrarySection {
                    id: librarySectionInstance
                    kanadeWin: kanadeWin
                    sectionActive: kanadeWin.section === "library"
                }

                DeviceSection {
                    id: deviceSectionInstance
                    kanadeWin: kanadeWin
                    sectionActive: kanadeWin.section === "device"
                }

                FoldersSection {
                    id: foldersSectionInstance
                    kanadeWin: kanadeWin
                    sectionActive: kanadeWin.section === "folders"
                }
            }
        }

        TrackDetailsPanel {
            id: trackDetailsPanel
            kanadeWin: kanadeWin
            anchors { top: titleBar.bottom; right: parent.right; bottom: parent.bottom }
        }
    }

    IpcHandler {
        target: "kanade"
        function toggle(): void { kanadeWin.visible = !kanadeWin.visible }
        function show(): void { kanadeWin.visible = true }
        function hide(): void { kanadeWin.visible = false }
    }
}

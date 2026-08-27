import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import "../DivaPaint.js" as DivaPaint

Item {
    id: customizationSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: customizationSection.slideY }

    function refreshPfpModel() {
        pfpModel.folder = ""
        pfpModel.folder = Qt.binding(function() { return "file://" + settingsWin.pfpDir })
    }

    function refreshStartIconModel() {
        startIconModel.folder = ""
        startIconModel.folder = Qt.binding(function() { return "file://" + settingsWin.startIconDir })
    }

    property int cursorPreviewGen: 0
    function refreshCursorPreviews() {
        customizationSection.cursorPreviewGen++
    }

    readonly property string homeDir: Quickshell.env("HOME")
    property string logoDir: customizationSection.homeDir + "/Pictures/Mirai/Logos"
    property string logoStatePath: customizationSection.homeDir + "/.cache/qs-fastfetch-logo-path"
    property string logoPath: ""

    function setLogo(path) {
        customizationSection.logoPath = path
        saveLogoProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + customizationSection.logoStatePath + "\" <<'LOGO_EOF'\n" + path + "\nLOGO_EOF\n"]
        saveLogoProc.running = false
        saveLogoProc.running = true
    }

    function ensureDir() {
        ensureLogoDirProc.running = false
        ensureLogoDirProc.running = true
    }

    property string layoutLuaPath: settingsWin.homeDir + "/.config/hypr/layout.lua"
    property string tilingLayout: "dwindle"

    function setTilingLayout(name) {
        customizationSection.tilingLayout = name
        applyLayoutProc.command = ["hyprctl", "eval", "hl.config({general = {layout = '" + name + "'}})"]
        applyLayoutProc.running = false
        applyLayoutProc.running = true
        saveLayoutProc.command = ["bash", "-c", "cat > \"" + customizationSection.layoutLuaPath + "\" <<'LAYOUT_LUA_EOF'\n" + customizationSection.buildLayoutLua() + "\nLAYOUT_LUA_EOF\n"]
        saveLayoutProc.running = false
        saveLayoutProc.running = true
    }

    function buildLayoutLua() {
        return "-- Managed by qs-settings (customization page). Edits here may be overwritten.\n\n" +
            "hl.config({\n" +
            "    general = {\n" +
            "        layout = \"" + customizationSection.tilingLayout + "\",\n" +
            "    },\n" +
            "})\n"
    }

    Process { id: applyLayoutProc; command: []; running: false }
    Process { id: saveLayoutProc; command: []; running: false }

    Component.onCompleted: { loadLogoProc.running = true; loadLayoutProc.running = true }

    Process {
        id: loadLayoutProc
        command: ["hyprctl", "getoption", "-j", "general:layout"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (parsed.str === "dwindle" || parsed.str === "master") customizationSection.tilingLayout = parsed.str
                } catch (_) {}
            }
        }
    }

    Process {
        id: loadLogoProc
        command: ["cat", customizationSection.logoStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { customizationSection.logoPath = text.trim() }
        }
    }

    Process {
        id: saveLogoProc
        command: ["true"]
        running: false
    }

    Process {
        id: ensureLogoDirProc
        command: ["mkdir", "-p", customizationSection.logoDir]
        running: false
        onExited: {
            logoModel.folder = ""
            logoModel.folder = Qt.binding(function() { return "file://" + customizationSection.logoDir })
        }
    }

    Process {
        id: openLogoDirProc
        command: ["nautilus", customizationSection.logoDir]
        running: false
    }

    Item {
        id: customizationHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
            label: "customization"
        }
    }

    Flickable {
        anchors { top: customizationHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: customContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: customContent
            width: parent.width
            spacing: 12
            topPadding: 4
            leftPadding: 16
            rightPadding: 16
            bottomPadding: 16

            component LayoutBtn: Item {
                property string label: ""
                property bool active: false
                signal clicked()
                width: 84; height: 26
                onActiveChanged: layoutBtnCanvas.requestPaint()

                Canvas {
                    id: layoutBtnCanvas
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
                    onPaint: DivaPaint.paintFacetPill(layoutBtnCanvas, parent.active ? 1.0 : Math.max(hp, 0), 5)
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.label
                    color: layoutBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: layoutBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: layoutBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                    onPositionChanged: mouse => {
                        layoutBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                        layoutBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                    }
                    onClicked: parent.clicked()
                }
            }

            component CsToggle: Item {
                property bool checked: false
                signal toggled()
                width: 40; height: 22

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: parent.checked ? "#39c5bb" : "#2a2a2a"
                    border.color: parent.checked ? "#39c5bb" : "#3a3a3a"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.checked ? parent.width - width - 3 : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.toggled()
                }
            }

            SectionCard {
                title: "bar widgets"

                Item {
                    width: parent.width
                    height: 44

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12; right: showPerfToggle.left; rightMargin: 10 }
                        text: "show performance"
                        color: "#999999"
                        font.pixelSize: 11; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    CsToggle {
                        id: showPerfToggle
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                        checked: settingsWin.showPerf
                        onToggled: settingsWin.setShowPerf(!settingsWin.showPerf)
                    }
                }

                Item {
                    width: parent.width
                    height: 44

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12; right: showWeatherToggle.left; rightMargin: 10 }
                        text: "show weather"
                        color: "#999999"
                        font.pixelSize: 11; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    CsToggle {
                        id: showWeatherToggle
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                        checked: settingsWin.showWeather
                        onToggled: settingsWin.setShowWeather(!settingsWin.showWeather)
                    }
                }
            }

            SectionCard {
                title: "layout behaviour"
                status: customizationSection.tilingLayout

                Item {
                    width: parent.width
                    height: 50

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        spacing: 8

                        LayoutBtn {
                            label: "dwindle"
                            active: customizationSection.tilingLayout === "dwindle"
                            onClicked: customizationSection.setTilingLayout("dwindle")
                        }

                        LayoutBtn {
                            label: "master"
                            active: customizationSection.tilingLayout === "master"
                            onClicked: customizationSection.setTilingLayout("master")
                        }
                    }
                }
            }

            FolderListModel {
                id: pfpModel
                folder: "file://" + settingsWin.pfpDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
                showDirs: false
            }

            SectionCard {
                title: "profile picture"
                path: settingsWin.pfpDir
                status: settingsWin.pfpDir
                onFolderClicked: {
                    settingsWin.ensurePfpDirProc.running = false
                    settingsWin.ensurePfpDirProc.running = true
                    settingsWin.openPfpDirProc.running = false
                    settingsWin.openPfpDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 208

                    GridView {
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 108; cellHeight: 108
                        clip: true
                        model: pfpModel

                        delegate: Item {
                            id: pfpTileRoot
                            width: 108; height: 108
                            readonly property bool selected: settingsWin.pfpPath === model.filePath

                            Canvas {
                                id: pfpCellCanvas
                                anchors.fill: parent
                                anchors.margins: 2
                                property real hoverProgress: 0.0
                                property real activeProgress: pfpTileRoot.selected ? 1.0 : 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onActiveProgressChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(pfpCellCanvas, Math.max(hoverProgress, activeProgress), 8)
                            }

                            Item {
                                id: pfpTile
                                anchors.fill: parent
                                anchors.margins: 14

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#181818"
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

                                Rectangle {
                                    z: 10
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: pfpTileRoot.selected ? "#39c5bb" : "transparent"
                                    border.width: 2
                                }
                            }

                            MouseArea {
                                anchors.fill: pfpCellCanvas
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: pfpCellCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    pfpCellCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    pfpCellCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: settingsWin.setPfp(model.filePath)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: pfpModel.count === 0
                        text: "no images found\n" + settingsWin.pfpDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            FolderListModel {
                id: startIconModel
                folder: "file://" + settingsWin.startIconDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.svg", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.SVG"]
                showDirs: false
            }

            SectionCard {
                title: "start button icon"
                path: settingsWin.startIconDir
                status: settingsWin.startIconDir
                onFolderClicked: {
                    settingsWin.ensureStartIconDirProc.running = false
                    settingsWin.ensureStartIconDirProc.running = true
                    settingsWin.openStartIconDirProc.running = false
                    settingsWin.openStartIconDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 92

                    ListView {
                        id: startIconListView
                        anchors.fill: parent
                        anchors { leftMargin: 14; rightMargin: 14; topMargin: 4; bottomMargin: 10 }
                        orientation: ListView.Horizontal
                        spacing: 10
                        clip: true

                        model: startIconModel
                        delegate: Item {
                            id: startIconTile
                            width: 64; height: 64
                            readonly property bool selected: settingsWin.startIconPath === model.filePath

                            Canvas {
                                id: startIconCanvas
                                anchors.fill: parent
                                property real hoverProgress: 0.0
                                property real activeProgress: startIconTile.selected ? 1.0 : 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onActiveProgressChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(startIconCanvas, Math.max(hoverProgress, activeProgress), 6)
                            }

                            Image {
                                anchors { fill: parent; margins: 12 }
                                source: "file://" + model.filePath
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: startIconCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    startIconCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    startIconCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: settingsWin.setStartIconImage(model.filePath)
                            }
                        }

                        header: Item {
                            id: startIconDefaultTile
                            width: 64; height: 64
                            readonly property bool selected: settingsWin.startIconPath === ""

                            Canvas {
                                id: startIconDefaultCanvas
                                anchors.fill: parent
                                property real hoverProgress: 0.0
                                property real activeProgress: startIconDefaultTile.selected ? 1.0 : 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onActiveProgressChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(startIconDefaultCanvas, Math.max(hoverProgress, activeProgress), 6)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: settingsWin.defaultStartIcon
                                color: startIconDefaultTile.selected ? "#0a1a1a" : "#39c5bb"
                                font.pixelSize: 22
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onContainsMouseChanged: startIconDefaultCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    startIconDefaultCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    startIconDefaultCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.setStartIconImage("")
                            }
                        }

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 74 }
                            visible: startIconModel.count === 0
                            text: "no images found in " + settingsWin.startIconDir
                            color: "#444444"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }
                }
            }

            FolderListModel {
                id: logoModel
                folder: "file://" + customizationSection.logoDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.GIF"]
                showDirs: false
            }

            SectionCard {
                title: "fastfetch logo"
                path: customizationSection.logoDir
                status: customizationSection.logoPath !== "" ? customizationSection.logoPath.split("/").pop() : "default"
                statusColor: customizationSection.logoPath !== "" ? "#39c5bb" : "#444444"
                onFolderClicked: {
                    customizationSection.ensureDir()
                    openLogoDirProc.running = false
                    openLogoDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 208

                    GridView {
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 108; cellHeight: 108
                        clip: true
                        model: logoModel

                        delegate: Item {
                            id: logoTileRoot
                            width: 108; height: 108
                            readonly property bool selected: customizationSection.logoPath === model.filePath

                            Canvas {
                                id: logoCellCanvas
                                anchors.fill: parent
                                anchors.margins: 2
                                property real hoverProgress: 0.0
                                property real activeProgress: logoTileRoot.selected ? 1.0 : 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onActiveProgressChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(logoCellCanvas, Math.max(hoverProgress, activeProgress), 8)
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 16
                                source: "file://" + model.filePath
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            MouseArea {
                                anchors.fill: logoCellCanvas
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: logoCellCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    logoCellCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    logoCellCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: customizationSection.setLogo(model.filePath)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: logoModel.count === 0
                        text: "no images found\n" + customizationSection.logoDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Process {
                id: listCursorThemesProc
                command: ["bash", "-c", "for base in /usr/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$base\" ] || continue; for d in \"$base\"/*/; do n=$(basename \"$d\"); [ -d \"${d}cursors\" ] && echo \"$n\"; done; done | sort -u"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        cursorThemeListModel.themes = text.trim().length > 0 ? text.trim().split("\n") : []
                    }
                }
            }

            QtObject {
                id: cursorThemeListModel
                property var themes: []
            }

            SectionCard {
                title: "cursor"
                path: settingsWin.cursorThemesDir
                status: settingsWin.cursorApplied ? "applied" : (settingsWin.cursorError.length > 0 ? settingsWin.cursorError : settingsWin.cursorTheme + " @ " + settingsWin.cursorSize + "px")
                statusColor: settingsWin.cursorApplied ? "#39c5bb" : (settingsWin.cursorError.length > 0 ? "#cc6666" : "#444444")
                onFolderClicked: {
                    openCursorThemesDirProc.running = false
                    openCursorThemesDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 116

                    GridView {
                        id: cursorThemeGrid
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 100; cellHeight: 100
                        clip: true
                        model: cursorThemeListModel.themes

                        delegate: Item {
                            id: cursorThemeTile
                            width: 92; height: 92
                            readonly property bool selected: settingsWin.cursorTheme === modelData

                            Canvas {
                                id: cursorThemeCanvas
                                anchors.fill: parent
                                property real hoverProgress: 0.0
                                property real activeProgress: cursorThemeTile.selected ? 1.0 : 0.0
                                property real mx: 0.5
                                property real my: 0.5
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onActiveProgressChanged: requestPaint()
                                onMxChanged: requestPaint()
                                onMyChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(cursorThemeCanvas, Math.max(hoverProgress, activeProgress), 7)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    property int gen: customizationSection.cursorPreviewGen
                                    source: gen >= 0 ? "file://" + settingsWin.cursorPreviewsDir + "/" + modelData + ".png" : ""
                                    width: 28; height: 28
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: false
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 80
                                    text: modelData
                                    color: cursorThemeTile.selected ? "#0a1a1a" : (cursorThemeArea.containsMouse ? "#ffffff" : "#999999")
                                    font.pixelSize: 9; font.family: "monospace"
                                    font.bold: cursorThemeTile.selected
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            MouseArea {
                                id: cursorThemeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: cursorThemeCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    cursorThemeCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    cursorThemeCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: settingsWin.applyCursor(modelData, settingsWin.cursorSize)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: cursorThemeListModel.themes.length === 0
                        text: "no cursor themes found\n" + settingsWin.cursorThemesDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 44

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                        text: "size"
                        color: "#666666"
                        font.pixelSize: 10; font.family: "monospace"
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                        spacing: 10

                        Repeater {
                            model: [16, 24, 32, 48, 64]

                            Item {
                                id: cursorSizeTile
                                width: 34; height: 34
                                readonly property bool selected: settingsWin.cursorSize === modelData

                                Canvas {
                                    id: cursorSizeCanvas
                                    anchors.fill: parent
                                    property real hoverProgress: 0.0
                                    property real activeProgress: cursorSizeTile.selected ? 1.0 : 0.0
                                    property real mx: 0.5
                                    property real my: 0.5
                                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                    Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                    onHoverProgressChanged: requestPaint()
                                    onActiveProgressChanged: requestPaint()
                                    onMxChanged: requestPaint()
                                    onMyChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: DivaPaint.paintFacetPill(cursorSizeCanvas, Math.max(hoverProgress, activeProgress), 5)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: cursorSizeTile.selected ? "#0a1a1a" : (cursorSizeArea.containsMouse ? "#ffffff" : "#999999")
                                    font.pixelSize: 10; font.family: "monospace"
                                    font.bold: cursorSizeTile.selected
                                }

                                MouseArea {
                                    id: cursorSizeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: cursorSizeCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                    onPositionChanged: mouse => {
                                        cursorSizeCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                        cursorSizeCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                    }
                                    onClicked: settingsWin.applyCursor(settingsWin.cursorTheme, modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

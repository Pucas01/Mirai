import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import "./DivaPaint.js" as DivaPaint

Window {
    id: switcherWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-wallpaper-switcher"
    color: "transparent"
    width: 900
    height: 480
    visible: false

    readonly property string homeDir: Quickshell.env("HOME")
    property string wallpaperDir: switcherWin.homeDir + "/Pictures/Mirai/Wallpapers"
    property string wallpaperStatePath: switcherWin.homeDir + "/.cache/qs-wallpaper-path"
    property string appliedWallpaper: ""
    property string pendingPath: ""
    property string pendingName: ""
    property string pathToSelect: ""

    function open() {
        pathToSelect = ""
        visible = true
        focusTimer.start()
        loadAppliedProc.running = false
        loadAppliedProc.running = true
    }

    function closeSwitcher() { visible = false }

    onClosing: close => { close.accepted = true }

    Timer { id: focusTimer; interval: 10; onTriggered: grid.forceActiveFocus() }

    Process {
        id: loadAppliedProc
        command: ["cat", switcherWin.wallpaperStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                switcherWin.appliedWallpaper = text.trim()
                switcherWin.pathToSelect = switcherWin.appliedWallpaper
                grid.currentIndex = 0
                grid.positionViewAtIndex(0, ListView.Center)
            }
        }
    }

    Process { id: applyProc; command: []; running: false }
    Process { id: saveStateProc; command: []; running: false }

    function confirmSelection() {
        if (switcherWin.pendingPath === "") { switcherWin.closeSwitcher(); return }
        var path = switcherWin.pendingPath
        switcherWin.appliedWallpaper = path
        applyProc.command = ["awww", "img", path, "--transition-type", "grow", "--transition-pos", "center", "--transition-duration", "0.8"]
        applyProc.running = false
        applyProc.running = true
        saveStateProc.command = ["bash", "-c", "mkdir -p ~/.cache && printf '%s' \"" + path + "\" > \"" + switcherWin.wallpaperStatePath + "\""]
        saveStateProc.running = false
        saveStateProc.running = true
        switcherWin.closeSwitcher()
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + switcherWin.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
        showDirs: false
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: "#e6232323" }
            GradientStop { position: 0.5;  color: "#f0181818" }
            GradientStop { position: 1.0;  color: "#f7101010" }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: switcherWin.closeSwitcher()
        }
    }

    Item {
        id: content
        anchors.fill: parent

        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 28 }
            height: 58

            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                spacing: 10

                Rectangle { width: 3; height: 22; color: "#39c5bb"; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CHOOSE A WALLPAPER"
                    color: "#ffffff"
                    font.pixelSize: 16; font.family: "Orbitron"; font.bold: true
                    font.letterSpacing: 2
                }
            }

            Text {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 34 }
                text: wallpaperModel.count > 0 ? switcherWin.pendingName : "no wallpapers found"
                color: "#8ff5f0"
                font.pixelSize: 11; font.family: "monospace"
            }
        }

        Item {
            id: carouselArea
            anchors { top: header.bottom; bottom: footer.top; left: parent.left; right: parent.right }

            Rectangle {
                anchors.centerIn: parent
                width: 340; height: 220
                radius: 140
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#0039c5bb" }
                    GradientStop { position: 0.5; color: "#3339c5bb" }
                    GradientStop { position: 1.0; color: "#0039c5bb" }
                }
            }

        ListView {
            id: grid
            anchors.centerIn: parent
            width: parent.width
            height: 260
            orientation: ListView.Horizontal
            model: wallpaperModel
            spacing: 28
            preferredHighlightBegin: width / 2 - 210
            preferredHighlightEnd: width / 2 + 210
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 260
            highlightMoveVelocity: -1
            cacheBuffer: 2000
            focus: true
            keyNavigationWraps: false
            keyNavigationEnabled: false

            Keys.onLeftPressed: grid.decrementCurrentIndex()
            Keys.onRightPressed: grid.incrementCurrentIndex()
            Keys.onReturnPressed: switcherWin.confirmSelection()
            Keys.onEnterPressed: switcherWin.confirmSelection()
            Keys.onEscapePressed: switcherWin.closeSwitcher()

            delegate: Item {
                id: wpDelegate
                width: 380; height: grid.height

                readonly property real absDist: Math.min(2.0, Math.abs(index - grid.currentIndex))
                readonly property real focusAmount: Math.max(0, 1.0 - absDist)
                readonly property bool selected: index === grid.currentIndex

                scale: 0.72 + focusAmount * 0.28
                opacity: 0.35 + focusAmount * 0.65

                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                onSelectedChanged: if (selected) { switcherWin.pendingPath = model.filePath; switcherWin.pendingName = model.fileName }
                Component.onCompleted: {
                    if (selected) { switcherWin.pendingPath = model.filePath; switcherWin.pendingName = model.fileName }
                    if (switcherWin.pathToSelect !== "" && model.filePath === switcherWin.pathToSelect) {
                        grid.currentIndex = index
                        grid.positionViewAtIndex(index, ListView.Center)
                    }
                }

                Canvas {
                    id: wpCanvas
                    anchors.fill: parent
                    property real hp: wpDelegate.selected ? 1.0 : 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hp { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(wpCanvas, hp, 14)
                }

                Rectangle {
                    id: wpImageFrame
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#101010"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "file://" + model.filePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 28
                        color: "#99000000"
                        visible: wpDelegate.selected

                        Text {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                            text: model.fileName
                            color: "#e0f8f8"
                            font.pixelSize: 10; font.family: "monospace"
                            elide: Text.ElideRight
                        }
                    }
                }

                Canvas {
                    id: wpImageBorder
                    anchors.fill: wpImageFrame
                    property real hp: wpCanvas.hp
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width, h = height
                        ctx.clearRect(0, 0, w, h)

                        ctx.beginPath()
                        ctx.rect(0, 0, w, h)

                        ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"
                        ctx.lineWidth = 1
                        ctx.stroke()

                        if (hp > 0) {
                            ctx.strokeStyle = "rgba(150,245,245," + (hp * 0.95) + ")"
                            ctx.lineWidth = 1.4
                            ctx.stroke()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wpDelegate.selected) switcherWin.confirmSelection()
                        else grid.currentIndex = index
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                propagateComposedEvents: true
                onWheel: wheel => {
                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) grid.incrementCurrentIndex()
                    else grid.decrementCurrentIndex()
                }
            }
        }
        }

        Item {
            id: footer
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
            width: hintText.implicitWidth + 28; height: 26

            Canvas {
                id: hintCanvas
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: DivaPaint.paintFacetPill(hintCanvas, 0.0, 5)
            }

            Text {
                id: hintText
                anchors.centerIn: parent
                text: "← → browse   ·   enter apply   ·   esc cancel"
                color: "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { if (switcherWin.visible) switcherWin.closeSwitcher(); else switcherWin.open() }
        function show(): void { switcherWin.open() }
        function hide(): void { switcherWin.closeSwitcher() }
    }
}

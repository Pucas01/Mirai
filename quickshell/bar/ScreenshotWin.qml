import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

Window {
    id: screenshotWin
    property bool isOpen: false
    property string imagePath: ""
    property bool copied: false
    property bool saved: false
    property string pendingPath: ""
    property int trigger: 0
    signal editRequested(string path, int trig)
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 380
    height: 280
    visible: false

    onTriggerChanged: {
        if (!pendingPath) return
        imagePath = pendingPath
        saved = false
        copied = false
    }

    function show(x, y, path, trig) {
        pendingPath = path
        trigger = trig
        screenshotWin.x = x
        screenshotWin.y = y
        isOpen = false
        visible = true
        ssOpenTimer.start()
    }

    Timer { id: ssOpenTimer; interval: 10; onTriggered: screenshotWin.isOpen = true }
    Timer { id: ssHideTimer; interval: 220; onTriggered: screenshotWin.visible = false }

    Process {
        id: copyProc
        command: ["bash", "-c", "wl-copy < " + screenshotWin.imagePath]
        onExited: code => {
            if (code === 0) {
                screenshotWin.copied = true
                ssCopyCloseTimer.start()
            }
        }
    }

    Timer { id: ssCopyCloseTimer; interval: 600; onTriggered: { screenshotWin.isOpen = false; ssHideTimer.start() } }

    Process {
        id: saveProc
        property string dest: ""
        command: ["bash", "-c", "mkdir -p ~/Pictures/Screenshots && cp " + screenshotWin.imagePath + " " + dest]
        onExited: code => {
            if (code === 0) {
                screenshotWin.saved = true
                ssSaveCloseTimer.start()
            }
        }
    }

    Timer { id: ssSaveCloseTimer; interval: 600; onTriggered: { screenshotWin.isOpen = false; ssHideTimer.start() } }

    PanelBackground {
        id: ssRect
        anchors.fill: parent

        opacity: screenshotWin.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: screenshotWin.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: screenshotWin.isOpen ? 0 : -10
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: ssRect.width / 2; origin.y: 0; xScale: ssRect.scaleVal; yScale: ssRect.scaleVal },
            Translate { y: ssRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 8

            Rectangle {
                width: parent.width
                height: 222
                color: "#111111"
                clip: true

                Image {
                    id: ssImage
                    anchors.fill: parent
                    source: screenshotWin.imagePath !== "" ? ("file://" + screenshotWin.imagePath + "?t=" + screenshotWin.trigger) : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: screenshotWin.editRequested(screenshotWin.imagePath, screenshotWin.trigger)
                }
            }

            Row {
                width: parent.width
                spacing: 6

                component SsBtn: Item {
                    property string label: ""
                    property bool active: false
                    signal clicked()
                    width: (parent.width - 18) / 4
                    height: 30

                    Canvas {
                        id: ssBtnCanvas
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
                        onPaint: DivaPaint.paintFacetPill(ssBtnCanvas, parent.active ? 1.0 : Math.max(hp, 0), 5)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.label
                        color: ssBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: ssBtnArea
                        anchors.fill: parent; hoverEnabled: true
                        onContainsMouseChanged: ssBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            ssBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            ssBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: parent.clicked()
                    }
                }

                SsBtn {
                    label: screenshotWin.copied ? "copied!" : "copy"
                    active: screenshotWin.copied
                    onClicked: { copyProc.running = false; copyProc.running = true }
                }
                SsBtn {
                    label: screenshotWin.saved ? "saved!" : "save"
                    active: screenshotWin.saved
                    onClicked: {
                        if (screenshotWin.saved) return
                        var now = new Date()
                        var ts = now.getFullYear() + "" +
                            String(now.getMonth()+1).padStart(2,"0") +
                            String(now.getDate()).padStart(2,"0") + "_" +
                            String(now.getHours()).padStart(2,"0") +
                            String(now.getMinutes()).padStart(2,"0") +
                            String(now.getSeconds()).padStart(2,"0")
                        saveProc.dest = "~/Pictures/Screenshots/screenshot_" + ts + ".png"
                        saveProc.running = false
                        saveProc.running = true
                    }
                }
                SsBtn {
                    label: "edit"
                    onClicked: screenshotWin.editRequested(screenshotWin.imagePath, screenshotWin.trigger)
                }
                SsBtn {
                    label: "discard"
                    onClicked: { screenshotWin.isOpen = false; ssHideTimer.start() }
                }
            }
        }
    }
}

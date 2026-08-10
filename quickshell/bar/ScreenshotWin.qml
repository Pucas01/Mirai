import QtQuick
import Quickshell
import Quickshell.Io

Window {
    id: screenshotWin
    property bool isOpen: false
    property string imagePath: ""
    property bool copied: false
    property bool saved: false
    property string pendingPath: ""
    property int trigger: 0
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 310
    height: 240
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
                height: 182
                color: "#111111"
                clip: true

                Image {
                    anchors.fill: parent
                    source: screenshotWin.imagePath !== "" ? ("file://" + screenshotWin.imagePath + "?t=" + screenshotWin.trigger) : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }
            }

            Row {
                width: parent.width
                spacing: 6

                component SsBtn: Item {
                    property string label: ""
                    property bool active: false
                    signal clicked()
                    width: (parent.width - 12) / 3
                    height: 30

                    Canvas {
                        id: ssBtnCanvas
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
                        color: ssBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: ssBtnArea
                        anchors.fill: parent; hoverEnabled: true
                        onContainsMouseChanged: ssBtnCanvas.hp = containsMouse ? 1.0 : 0.0
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
                    label: "discard"
                    onClicked: { screenshotWin.isOpen = false; ssHideTimer.start() }
                }
            }
        }
    }
}

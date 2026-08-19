import QtQuick
import Quickshell

Window {
    id: performancePopup
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 300
    height: 402
    visible: false

    property real cpuPercent: 0
    property var cpuCorePercents: []
    property real cpuTempC: -1
    property real ramPercent: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property string uptimeText: ""

    property real gpuPercent: -1
    property real gpuTempC: -1
    property real gpuVramPercent: 0
    property real gpuVramUsedGb: 0
    property real gpuVramTotalGb: 0

    function open(x, y) {
        performancePopup.x = x
        performancePopup.y = y
        isOpen = false
        visible = true
        perfOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        perfCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: perfOpenTimer; interval: 10; onTriggered: performancePopup.isOpen = true }
    Timer { id: perfCloseTimer; interval: 220; onTriggered: performancePopup.visible = false }

    component SectionBanner: Item {
        property string label: ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        height: 26

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cut = 14, w = width, h = height
                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - cut)
                ctx.lineTo(w - cut, h); ctx.lineTo(0, h); ctx.closePath()
                var base = ctx.createLinearGradient(0, 0, 0, h)
                base.addColorStop(0, "#5a5a5a"); base.addColorStop(0.08, "#454545")
                base.addColorStop(0.5, "#3a3a3a"); base.addColorStop(1.0, "#2e2e2e")
                ctx.fillStyle = base
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5); ctx.lineTo(0, h * 0.5); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                gloss.addColorStop(0, "rgba(255,255,255,0.18)")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss
                ctx.fill()
            }
        }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
            text: parent.label.toUpperCase()
            color: "#ffffff"
            font.pixelSize: 11; font.family: "Orbitron"; font.bold: true
            font.letterSpacing: 2
        }
    }

    component StatBar: Item {
        id: statBar
        property string label: ""
        property real percent: 0
        property string valueText: ""
        property color barColor: "#39c5bb"
        width: parent.width
        height: 32

        Row {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Text {
                width: statBar.width * 0.4
                text: statBar.label
                color: "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
            Text {
                width: statBar.width * 0.6
                horizontalAlignment: Text.AlignRight
                text: statBar.valueText
                color: "#cccccc"
                font.pixelSize: 10; font.family: "monospace"
            }
        }

        Rectangle {
            id: statBarTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 6
            color: "#1c1c1c"
            border.color: "#2a2a2a"
            border.width: 1

            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 1 }
                height: parent.height - 2
                width: Math.max(0, (statBarTrack.width - 2) * Math.min(1, Math.max(0, statBar.percent / 100)))
                color: statBar.barColor
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }

    PopupCard {
        id: perfRect
        anchors.fill: parent

        opacity: performancePopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: performancePopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: performancePopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: perfRect.width / 2; origin.y: 0; xScale: perfRect.scaleVal; yScale: perfRect.scaleVal },
            Translate { y: perfRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item { width: 1; height: 12 }

            SectionBanner { label: "performance" }

            Item { width: 1; height: 12 }

            Item {
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                height: performancePopup.gpuPercent >= 0 ? 116 : 76

                StatBar {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    label: "cpu"
                    percent: performancePopup.cpuPercent
                    valueText: Math.round(performancePopup.cpuPercent) + "%" + (performancePopup.cpuTempC >= 0 ? "  ·  " + Math.round(performancePopup.cpuTempC) + "°C" : "")
                    barColor: performancePopup.cpuPercent >= 85 ? "#ff6b6b" : "#39c5bb"
                }

                StatBar {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 40 }
                    label: "memory"
                    percent: performancePopup.ramPercent
                    valueText: performancePopup.ramUsedGb.toFixed(1) + " / " + performancePopup.ramTotalGb.toFixed(1) + " GB"
                    barColor: performancePopup.ramPercent >= 90 ? "#ff6b6b" : "#39c5bb"
                }

                StatBar {
                    visible: performancePopup.gpuPercent >= 0
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 80 }
                    label: "gpu"
                    percent: performancePopup.gpuPercent
                    valueText: Math.round(performancePopup.gpuPercent) + "%" + (performancePopup.gpuTempC >= 0 ? "  ·  " + Math.round(performancePopup.gpuTempC) + "°C" : "")
                    barColor: performancePopup.gpuPercent >= 85 ? "#ff6b6b" : "#39c5bb"
                }
            }

            Item { width: 1; height: 8 }

            Item {
                visible: performancePopup.gpuPercent >= 0
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                height: visible ? 24 : 0

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "vram"
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: performancePopup.gpuVramUsedGb.toFixed(1) + " / " + performancePopup.gpuVramTotalGb.toFixed(1) + " GB"
                    color: "#cccccc"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            Item { width: 1; height: performancePopup.gpuPercent >= 0 ? 8 : 0 }

            SectionBanner { label: "cores" }

            Item { width: 1; height: 10 }

            Item {
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                height: Math.ceil(performancePopup.cpuCorePercents.length / 4) * 26

                Grid {
                    anchors.fill: parent
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 6

                    Repeater {
                        model: performancePopup.cpuCorePercents

                        delegate: Item {
                            required property real modelData
                            required property int index
                            width: (perfRect.width - 28 - 24) / 4
                            height: 20

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: index
                                color: "#666666"
                                font.pixelSize: 8; font.family: "monospace"
                                width: 12
                            }

                            Rectangle {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                                height: 6
                                color: "#1c1c1c"
                                border.color: "#2a2a2a"
                                border.width: 1

                                Rectangle {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 1 }
                                    height: parent.height - 2
                                    width: Math.max(0, (parent.width - 2) * Math.min(1, Math.max(0, modelData / 100)))
                                    color: modelData >= 85 ? "#ff6b6b" : "#39c5bb"
                                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }

            SectionBanner { label: "system" }

            Item { width: 1; height: 10 }

            Item {
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                height: 24

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "uptime"
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: performancePopup.uptimeText
                    color: "#cccccc"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            Item { width: 1; height: 12 }
        }
    }
}

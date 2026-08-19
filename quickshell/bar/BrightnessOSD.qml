import QtQuick
import QtQuick.Effects
import Quickshell
import "./DivaPaint.js" as DivaPaint

Window {
    id: brightnessOsd
    property bool isOpen: false
    property real brightness: 1
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 220
    height: 64
    visible: false

    function show(x, y) {
        brightnessOsd.x = x
        brightnessOsd.y = y
        isOpen = false
        visible = true
        osdOpenTimer.start()
        osdAutoClose.restart()
    }

    Timer { id: osdOpenTimer; interval: 10; onTriggered: brightnessOsd.isOpen = true }
    Timer { id: osdAutoClose; interval: 1400; onTriggered: { brightnessOsd.isOpen = false; osdHideTimer.start() } }
    Timer { id: osdHideTimer; interval: 220; onTriggered: brightnessOsd.visible = false }

    PopupCard {
        id: osdRect
        anchors.fill: parent
        clip: true

        opacity: brightnessOsd.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: brightnessOsd.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: brightnessOsd.isOpen ? 0 : -10
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: osdRect.width / 2; origin.y: 0; xScale: osdRect.scaleVal; yScale: osdRect.scaleVal },
            Translate { y: osdRect.slideY }
        ]

        Row {
            anchors { fill: parent; margins: 14 }
            spacing: 12

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32

                Canvas {
                    id: brightnessOsdIconCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(brightnessOsdIconCanvas, 0.0, 6, DivaPaint.ACCENT_AMBER)
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰃟"
                    color: "#f5c542"
                    font.pixelSize: 17
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - 12
                spacing: 6

                Rectangle {
                    id: brightnessOsdTrack
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#1c1c1c"
                    border.color: "#333333"
                    border.width: 1

                    Rectangle {
                        id: brightnessOsdFill
                        width: (parent.width - 2) * Math.max(0, Math.min(1, brightnessOsd.brightness))
                        height: parent.height - 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: 1
                        radius: 2
                        color: "#f5c542"
                        Behavior on width { NumberAnimation { duration: 100 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#f5c542"
                            shadowBlur: 0.6
                            shadowOpacity: 0.7
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            blurMax: 16
                            autoPaddingEnabled: true
                        }
                    }
                }

                Text {
                    text: Math.round(brightnessOsd.brightness * 100) + "%"
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }
        }
    }
}

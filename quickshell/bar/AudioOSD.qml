import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import "./DivaPaint.js" as DivaPaint

Window {
    id: audioOsd
    property bool isOpen: false
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 220
    height: 64
    visible: false

    property bool muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
    property real volume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0

    function show(x, y) {
        audioOsd.x = x
        audioOsd.y = y
        isOpen = false
        visible = true
        osdOpenTimer.start()
        osdAutoClose.restart()
    }

    Timer { id: osdOpenTimer; interval: 10; onTriggered: audioOsd.isOpen = true }
    Timer { id: osdAutoClose; interval: 1400; onTriggered: { audioOsd.isOpen = false; osdHideTimer.start() } }
    Timer { id: osdHideTimer; interval: 220; onTriggered: audioOsd.visible = false }

    PopupCard {
        id: osdRect
        anchors.fill: parent
        clip:true

        opacity: audioOsd.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: audioOsd.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: audioOsd.isOpen ? 0 : -10
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
                    id: audioOsdIconCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(audioOsdIconCanvas, 0.0, 6, audioOsd.muted ? DivaPaint.ACCENT_RED : DivaPaint.ACCENT_TEAL)
                }

                Text {
                    anchors.centerIn: parent
                    text: audioOsd.muted ? "󰝟" : "󰕾"
                    color: audioOsd.muted ? "#ff8a8a" : "#39c5bb"
                    font.pixelSize: 17
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - 12
                spacing: 6

                Rectangle {
                    id: audioOsdTrack
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#1c1c1c"
                    border.color: "#333333"
                    border.width: 1

                    Rectangle {
                        id: audioOsdFill
                        width: (parent.width - 2) * Math.max(0, Math.min(1, audioOsd.volume))
                        height: parent.height - 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: 1
                        radius: 2
                        color: audioOsd.muted ? "#555555" : "#39c5bb"
                        Behavior on width { NumberAnimation { duration: 100 } }

                        layer.enabled: !audioOsd.muted
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#39c5bb"
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
                    text: audioOsd.muted ? "muted" : Math.round(audioOsd.volume * 100) + "%"
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }
        }
    }
}

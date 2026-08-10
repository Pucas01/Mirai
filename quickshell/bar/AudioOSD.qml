import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

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

    PanelBackground {
        id: osdRect
        anchors.fill: parent
        clip: true

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

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: audioOsd.muted ? "󰝟" : "󰕾"
                color: audioOsd.muted ? "#ff6b6b" : "#39c5bb"
                font.pixelSize: 20
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - 12
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: "#2a2a2a"

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, audioOsd.volume))
                        height: parent.height
                        radius: parent.radius
                        color: audioOsd.muted ? "#555555" : "#39c5bb"
                        Behavior on width { NumberAnimation { duration: 100 } }
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

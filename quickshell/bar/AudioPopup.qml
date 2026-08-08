import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Window {
    id: audioPopup
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 300
    height: 360
    visible: false

    function open(x, y) {
        audioPopup.x = x
        audioPopup.y = y
        isOpen = false
        visible = true
        audioOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        audioCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: audioOpenTimer; interval: 10; onTriggered: audioPopup.isOpen = true }
    Timer { id: audioCloseTimer; interval: 220; onTriggered: audioPopup.visible = false }

    property bool sliderActive: false
    function markSliderActive() {
        sliderActive = true
        sliderActiveResetTimer.restart()
    }
    Timer { id: sliderActiveResetTimer; interval: 300; onTriggered: audioPopup.sliderActive = false }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var playbackStreams: Pipewire.ready
        ? Pipewire.nodes.values.filter(function(n) { return n.isStream && (n.type & PwNodeType.AudioOutStream) })
        : []

    component VolumeSlider: Item {
        property real value: 0
        property bool muted: false
        signal moved(real v)
        height: 20

        Rectangle {
            id: sliderTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 2.5
            color: "#2a2a2a"

            Rectangle {
                width: sliderTrack.width * Math.max(0, Math.min(1, parent.parent.value))
                height: parent.height
                radius: parent.radius
                color: parent.parent.muted ? "#555555" : "#39c5bb"
                Behavior on width { NumberAnimation { duration: 60 } }
            }
        }

        MouseArea {
            anchors { fill: parent; margins: -4 }
            cursorShape: Qt.PointingHandCursor
            function updateFromX(mx) {
                audioPopup.markSliderActive()
                moved(Math.max(0, Math.min(1, mx / width)))
            }
            onPressed: mouse => updateFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
            onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                audioPopup.markSliderActive()
                moved(Math.max(0, Math.min(1, value + step)))
            }
        }
    }

    component MuteBtn: Item {
        property bool muted: false
        signal toggled()
        width: 26; height: 26

        Text {
            anchors.centerIn: parent
            text: parent.muted ? "󰝟" : "󰕾"
            color: muteArea.containsMouse ? "#ffffff" : (parent.muted ? "#ff6b6b" : "#999999")
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    Rectangle {
        id: audioRect
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#39c5bb"
        border.width: 1

        opacity: audioPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: audioPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: audioPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: audioRect.width / 2; origin.y: 0; xScale: audioRect.scaleVal; yScale: audioRect.scaleVal },
            Translate { y: audioRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 60

                MuteBtn {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                    onToggled: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                }

                VolumeSlider {
                    anchors { left: parent.left; right: masterPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 50; rightMargin: 10 }
                    value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                    muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                    onMoved: v => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v }
                }

                Text {
                    id: masterPctText
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            Item {
                width: parent.width
                height: 24
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: "applications"
                    color: "#666666"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            ListView {
                width: parent.width
                height: parent.height - 60 - 1 - 24
                clip: true
                model: audioPopup.playbackStreams
                spacing: 2

                delegate: Item {
                    id: streamRow
                    required property var modelData
                    width: ListView.view.width
                    height: 44

                    Text {
                        anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 4; right: parent.right; rightMargin: 14 }
                        text: streamRow.modelData.properties["application.name"] || streamRow.modelData.description || streamRow.modelData.name
                        color: "#cccccc"
                        font.pixelSize: 10; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    MuteBtn {
                        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 10; bottomMargin: 2 }
                        width: 22; height: 18
                        muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                        onToggled: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                    }

                    VolumeSlider {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 38; rightMargin: 44; bottomMargin: 5 }
                        value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                        muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                        onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
                    }

                    Text {
                        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 14; bottomMargin: 5 }
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: audioPopup.playbackStreams.length === 0
                    text: "nothing playing"
                    color: "#444444"
                    font.pixelSize: 11; font.family: "monospace"
                }
            }
        }
    }
}

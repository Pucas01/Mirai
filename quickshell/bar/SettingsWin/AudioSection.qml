import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: audioSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: audioSection.slideY }

    property bool sliderActive: false
    function markSliderActive() {
        sliderActive = true
        sliderActiveResetTimer.restart()
    }
    Timer { id: sliderActiveResetTimer; interval: 300; onTriggered: audioSection.sliderActive = false }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var outputDevices: Pipewire.ready
        ? Pipewire.nodes.values.filter(function(n) { return !n.isStream && (n.type & PwNodeType.AudioSink) })
        : []
    property var inputDevices: Pipewire.ready
        ? Pipewire.nodes.values.filter(function(n) { return !n.isStream && (n.type & PwNodeType.AudioSource) })
        : []
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
                audioSection.markSliderActive()
                moved(Math.max(0, Math.min(1, mx / width)))
            }
            onPressed: mouse => updateFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
            onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                audioSection.markSliderActive()
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

    component DeviceRow: Item {
        property var node: null
        property bool active: false
        signal selected()
        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors.fill: parent
            color: deviceRowArea.containsMouse ? "#242424" : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }

            Rectangle {
                width: 2; height: parent.height * 0.55
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                color: "#39c5bb"
                opacity: parent.parent.active ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14; right: parent.right; rightMargin: 8 }
                text: parent.parent.node ? (parent.parent.node.description || parent.parent.node.nickname || parent.parent.node.name) : ""
                color: parent.parent.active ? "#ffffff" : "#999999"
                font.pixelSize: 11; font.family: "monospace"
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: deviceRowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.selected()
        }
    }

    Item {
        id: audioHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
            label: "audio"
        }
    }

    Flickable {
        anchors { top: audioHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: audioContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: audioContent
            width: parent.width
            spacing: 12
            topPadding: 4
            leftPadding: 16
            rightPadding: 16
            bottomPadding: 16

            SectionCard {
                title: "output device"

                Column {
                    width: parent.width
                    Repeater {
                        model: audioSection.outputDevices
                        delegate: DeviceRow {
                            required property var modelData
                            node: modelData
                            active: Pipewire.defaultAudioSink === modelData
                            onSelected: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 40
                    visible: Pipewire.defaultAudioSink !== null

                    MuteBtn {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                        onToggled: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                    }

                    VolumeSlider {
                        anchors { left: parent.left; right: outputPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 44; rightMargin: 10 }
                        value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                        muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                        onMoved: v => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v }
                    }

                    Text {
                        id: outputPctText
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                        color: "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }
            }

            SectionCard {
                title: "input device"

                Column {
                    width: parent.width
                    Repeater {
                        model: audioSection.inputDevices
                        delegate: DeviceRow {
                            required property var modelData
                            node: modelData
                            active: Pipewire.defaultAudioSource === modelData
                            onSelected: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 40
                    visible: Pipewire.defaultAudioSource !== null

                    MuteBtn {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        muted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
                        onToggled: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                    }

                    VolumeSlider {
                        anchors { left: parent.left; right: inputPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 44; rightMargin: 10 }
                        value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
                        muted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
                        onMoved: v => { if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = v }
                    }

                    Text {
                        id: inputPctText
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "--"
                        color: "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }
            }

            SectionCard {
                title: "applications"

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: audioSection.playbackStreams
                        delegate: Item {
                            id: streamRow
                            required property var modelData
                            width: parent ? parent.width : 0
                            height: 40

                            Text {
                                anchors { left: parent.left; top: parent.top; leftMargin: 16; topMargin: 2; right: parent.right; rightMargin: 16 }
                                text: streamRow.modelData.properties["application.name"] || streamRow.modelData.description || streamRow.modelData.name
                                color: "#cccccc"
                                font.pixelSize: 10; font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            MuteBtn {
                                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 12; bottomMargin: 2 }
                                width: 22; height: 18
                                muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                onToggled: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                            }

                            VolumeSlider {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40; rightMargin: 46; bottomMargin: 4 }
                                value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                                muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
                            }

                            Text {
                                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 4 }
                                width: 34
                                horizontalAlignment: Text.AlignRight
                                text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                                color: "#666666"
                                font.pixelSize: 9; font.family: "monospace"
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: audioSection.playbackStreams.length === 0
                        text: "nothing playing"
                        color: "#444444"
                        font.pixelSize: 10; font.family: "monospace"
                        topPadding: 10
                        bottomPadding: 6
                    }
                }
            }
        }
    }
}

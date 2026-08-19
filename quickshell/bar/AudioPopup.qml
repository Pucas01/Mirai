import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import "./DivaPaint.js" as DivaPaint

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
        id: volSlider
        property real value: 0
        property bool muted: false
        readonly property bool hovered: sliderArea.containsMouse || sliderArea.pressed
        signal moved(real v)
        height: 20

        Rectangle {
            id: sliderTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 2.5
            color: "#1c1c1c"
            border.color: "#333333"
            border.width: 1

            Rectangle {
                id: sliderFill
                width: sliderTrack.width * Math.max(0, Math.min(1, volSlider.value))
                height: parent.height
                radius: parent.radius
                color: volSlider.muted ? "#555555" : "#39c5bb"
                Behavior on width { NumberAnimation { duration: 60 } }

                layer.enabled: !volSlider.muted
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#39c5bb"
                    shadowBlur: volSlider.hovered ? 0.7 : 0.4
                    shadowOpacity: volSlider.hovered ? 0.85 : 0.45
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: volSlider.hovered ? 20 : 10
                    autoPaddingEnabled: true
                }
            }

            Rectangle {
                id: sliderThumb
                x: sliderFill.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 11; height: 11; radius: 5.5
                color: "#ffffff"
                border.color: volSlider.muted ? "#555555" : "#39c5bb"
                border.width: 1.5
                scale: volSlider.hovered ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
        }

        MouseArea {
            id: sliderArea
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true
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
        id: muteBtn
        property bool muted: false
        signal toggled()
        width: 26; height: 26

        Canvas {
            id: muteBtnCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: DivaPaint.paintFacetPill(muteBtnCanvas, hp, 5, muteBtn.muted ? DivaPaint.ACCENT_RED : DivaPaint.ACCENT_TEAL)
        }

        Text {
            anchors.centerIn: parent
            text: muteBtn.muted ? "󰝟" : "󰕾"
            color: muteArea.containsMouse ? "#ffffff" : (muteBtn.muted ? "#ff8a8a" : "#999999")
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: muteBtnCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: muteBtn.toggled()
        }
    }

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

    Item {
        id: audioRect
        anchors.fill: parent

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

        Canvas {
            id: audioCardCanvas
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                var w = width, h = height, cut = 12
                ctx.clearRect(0, 0, w, h)

                function drawShape() {
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                    ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                    ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                }

                drawShape()
                var base = ctx.createLinearGradient(0, 0, 0, h)
                base.addColorStop(0, "#242424"); base.addColorStop(0.5, "#1c1c1c"); base.addColorStop(1.0, "#181818")
                ctx.fillStyle = base; ctx.fill()

                drawShape()
                ctx.save()
                ctx.clip()
                ctx.lineWidth = 6
                ctx.strokeStyle = "rgba(150,245,245,0.35)"
                ctx.stroke()
                ctx.restore()

                ctx.beginPath()
                ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                gloss.addColorStop(0, "rgba(255,255,255,0.08)")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss; ctx.fill()

                drawShape()
                ctx.strokeStyle = "#c0f4f4"
                ctx.lineWidth = 1
                ctx.stroke()

                drawShape()
                ctx.strokeStyle = "rgba(150,245,245,0.9)"
                ctx.lineWidth = 1.4
                ctx.stroke()
            }
        }

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

            SectionBanner { label: "applications" }
            Item { width: 1; height: 8 }

            ListView {
                width: parent.width
                height: parent.height - 60 - 26 - 8
                clip: true
                model: audioPopup.playbackStreams
                spacing: 2

                delegate: Item {
                    id: streamRow
                    required property var modelData
                    property string appName: streamRow.modelData.properties["application.name"] || streamRow.modelData.description || streamRow.modelData.name
                    property var appEntry: DesktopEntries.heuristicLookup(streamRow.appName)
                    width: ListView.view.width
                    height: 48

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 4 }
                        width: 20; height: 20
                        radius: 4
                        color: "#1c1c1c"
                        border.color: "#333333"
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            source: streamRow.appEntry && streamRow.appEntry.icon !== "" ? "image://icon/" + streamRow.appEntry.icon : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !streamRow.appEntry || streamRow.appEntry.icon === ""
                            text: "󰝚"
                            color: "#666666"
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        anchors { left: parent.left; top: parent.top; leftMargin: 36; topMargin: 4; right: parent.right; rightMargin: 14 }
                        text: streamRow.appName
                        color: "#cccccc"
                        font.pixelSize: 10; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Item {
                        id: streamControlRow
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
                        height: 20

                        MuteBtn {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                            width: 22; height: 18
                            muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                            onToggled: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                        }

                        VolumeSlider {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 38; rightMargin: 44 }
                            value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                            muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                            onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
                        }

                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                            color: "#666666"
                            font.pixelSize: 9; font.family: "monospace"
                        }
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

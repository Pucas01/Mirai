import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "./DivaPaint.js" as DivaPaint

Window {
    id: mediaPopup
    property bool isOpen: false
    property var activePlayer: null
    property var preferredPlayer: null
    property var displayPlayer: activePlayer
    property var cavaBars: []
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    readonly property int speakerSize: 196
    readonly property int infoWidth: 210
    readonly property int contentPadding: 10
    width: speakerSize + infoWidth + 2 + contentPadding * 2
    height: speakerSize + 2 + contentPadding * 2
    visible: false

    function open(x, y) {
        mediaPopup.x = x
        mediaPopup.y = y
        isOpen = false
        visible = true
        mediaOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        mediaCloseTimer.start()
    }

    onClosing: close => {
        if (isOpen) {
            close.accepted = false
            closePopup()
        }
    }

    onActivePlayerChanged: {
        if (activePlayer === mediaPopup.displayPlayer) return
        playerFadeOut.start()
    }

    SequentialAnimation {
        id: playerFadeOut
        NumberAnimation { target: mediaContent; property: "opacity"; to: 0; duration: 130; easing.type: Easing.OutCubic }
        ScriptAction { script: { mediaPopup.displayPlayer = mediaPopup.activePlayer } }
        NumberAnimation { target: mediaContent; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }

    Timer { id: mediaOpenTimer; interval: 10; onTriggered: mediaPopup.isOpen = true }
    Timer { id: mediaCloseTimer; interval: 220; onTriggered: mediaPopup.visible = false }

    property real livePosition: displayPlayer ? displayPlayer.position : 0
    Timer {
        interval: 500
        running: mediaPopup.isOpen && mediaPopup.displayPlayer && mediaPopup.displayPlayer.isPlaying
        repeat: true
        onTriggered: mediaPopup.livePosition = mediaPopup.displayPlayer.position
    }
    onDisplayPlayerChanged: livePosition = displayPlayer ? displayPlayer.position : 0

    function formatTime(sec) {
        if (!sec || sec < 0 || isNaN(sec)) return "0:00"
        var m = Math.floor(sec / 60)
        var s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    PopupCard {
        id: mediaRect
        anchors.fill: parent

        opacity: mediaPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: mediaPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: mediaPopup.isOpen ? 0 : -12
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: mediaRect.width / 2; origin.y: 0; xScale: mediaRect.scaleVal; yScale: mediaRect.scaleVal },
            Translate { y: mediaRect.slideY }
        ]


        Row {
            id: mediaContent
            anchors.fill: parent
            anchors.margins: mediaPopup.contentPadding
            spacing: 0

            Rectangle {
                id: artArea
                width: mediaPopup.speakerSize
                height: mediaPopup.speakerSize
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#1a1a1a" }
                    GradientStop { position: 0.5; color: "#141414" }
                    GradientStop { position: 1.0; color: "#0a0a0a" }
                }

                readonly property real level: {
                    var bars = mediaPopup.cavaBars
                    if (!bars || bars.length === 0) return 0
                    var sum = 0
                    for (var i = 0; i < bars.length; i++) sum += bars[i]
                    return Math.max(0, Math.min(1, (sum / bars.length) / 100))
                }
                readonly property bool playing: mediaPopup.displayPlayer && mediaPopup.displayPlayer.isPlaying

                Image {
                    id: artBackdropImage
                    anchors.fill: parent
                    source: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                    smooth: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: artBackdropImage
                    visible: mediaPopup.displayPlayer && mediaPopup.displayPlayer.trackArtUrl !== ""
                    opacity: 1
                    saturation: -0.2
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 48
                    autoPaddingEnabled: false
                }

                Item {
                    id: speakerStage
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.86
                    height: width

                    Image {
                        id: speakerBody
                        anchors.fill: parent
                        source: Quickshell.shellPath("bar/assets/speaker_body.svg")
                        sourceSize: Qt.size(width, height)
                        smooth: true
                        z: 0
                    }

                    Image {
                        id: speakerRingGlow
                        anchors.fill: parent
                        source: Quickshell.shellPath("bar/assets/speaker_ring.svg")
                        sourceSize: Qt.size(width, height)
                        smooth: true
                        scale: artArea.playing ? 1.0 + artArea.level * 0.45 : 1.0
                        opacity: artArea.playing ? artArea.level * 1.0 : 0.0
                        Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                        z: 1
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 32
                        }
                    }

                    Image {
                        id: speakerRing
                        anchors.fill: parent
                        source: Quickshell.shellPath("bar/assets/speaker_ring.svg")
                        sourceSize: Qt.size(width, height)
                        smooth: true
                        scale: artArea.playing ? 1.0 + artArea.level * 0.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        z: 2
                    }

                    Item {
                        id: artDisc
                        z: 3
                        anchors.centerIn: parent
                        width: parent.width * 0.37
                        height: width

                        Rectangle {
                            id: artDiscMask
                            anchors.fill: parent
                            radius: width / 2
                            color: "#000000"
                            visible: false
                        }

                        Image {
                            id: artDiscImage
                            anchors.fill: parent
                            source: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                            smooth: true
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: artDiscImage
                            visible: mediaPopup.displayPlayer && mediaPopup.displayPlayer.trackArtUrl !== ""
                            maskEnabled: true
                            maskSource: artDiscMask
                            saturation: -0.9
                            brightness: -0.08
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !mediaPopup.displayPlayer || mediaPopup.displayPlayer.trackArtUrl === ""
                            text: "♪"
                            color: "#8ff5f0"
                            font.pixelSize: parent.width * 0.4
                        }
                    }
                }

            }

            Item {
                id: infoPanel
                width: mediaPopup.infoWidth
                height: mediaPopup.speakerSize

                property real hoverProgress: 0.0
                Behavior on hoverProgress { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                HoverHandler {
                    id: infoHover
                    onHoveredChanged: infoPanel.hoverProgress = hovered ? 1.0 : 0.0
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 4
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(80/255, 80/255, 80/255, 0.31 + infoPanel.hoverProgress * 0.2) }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }

                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.margins: 14
                    anchors.topMargin: 10
                    spacing: 3

                    Text {
                        width: parent.width
                        text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackTitle : ""
                        color: "#e0e0e0"
                        font.pixelSize: 14
                        font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtist : ""
                        color: "#777777"
                        font.pixelSize: 12
                        font.family: "monospace"
                        elide: Text.ElideRight
                    }
                }

                Item {
                    id: progressArea
                    visible: mediaPopup.displayPlayer && mediaPopup.displayPlayer.length > 0
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 68 }
                    height: 40

                    readonly property real progressFrac: Math.max(0, Math.min(1, mediaPopup.displayPlayer && mediaPopup.displayPlayer.length > 0 ? mediaPopup.livePosition / mediaPopup.displayPlayer.length : 0))
                    readonly property int tickCount: Math.max(8, Math.floor(width / 7))

                    Row {
                        id: tickRow
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 14
                        spacing: (progressArea.width - progressArea.tickCount * 4) / Math.max(1, progressArea.tickCount - 1)

                        Repeater {
                            model: progressArea.tickCount
                            delegate: Rectangle {
                                required property int index
                                readonly property bool lit: progressArea.tickCount <= 1 ? true : (index / (progressArea.tickCount - 1)) <= progressArea.progressFrac
                                width: 4
                                height: lit ? 14 : 7
                                anchors.bottom: parent.bottom
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: lit ? "#8ff5f0" : "#3a3a3a" }
                                    GradientStop { position: 1.0; color: lit ? "#1f8a82" : "#242424" }
                                }
                                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: progressDragArea
                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tickRow.bottom }
                        enabled: mediaPopup.displayPlayer && mediaPopup.displayPlayer.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function seekToX(mx) {
                            if (!mediaPopup.displayPlayer || mediaPopup.displayPlayer.length <= 0) return
                            var frac = Math.max(0, Math.min(1, mx / width))
                            var newPos = frac * mediaPopup.displayPlayer.length
                            mediaPopup.displayPlayer.position = newPos
                            mediaPopup.livePosition = newPos
                        }
                        onPressed: mouse => seekToX(mouse.x)
                        onPositionChanged: mouse => { if (pressed) seekToX(mouse.x) }
                    }

                    Text {
                        anchors { left: parent.left; top: tickRow.bottom; topMargin: 5 }
                        text: mediaPopup.formatTime(mediaPopup.livePosition)
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                    }

                    Text {
                        anchors { right: parent.right; top: tickRow.bottom; topMargin: 5 }
                        text: mediaPopup.displayPlayer ? mediaPopup.formatTime(mediaPopup.displayPlayer.length) : "0:00"
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                }

                Row {
                    id: controlsRow
                    anchors { horizontalCenter: parent.horizontalCenter; top: progressArea.bottom; topMargin: 4 }
                    spacing: 10

                    component MediaBtn: Item {
                        id: mediaBtnRoot
                        width: 46
                        height: 32
                        property string sym: ""
                        property bool hero: false
                        onHeroChanged: btnCanvas.requestPaint()
                        signal activated()

                        Canvas {
                            id: btnCanvas
                            anchors.fill: parent
                            property real hoverProgress: 0.0
                            property real mx: 0.5
                            property real my: 0.5
                            property real pulse: 0.0
                            SequentialAnimation on pulse {
                                running: btnCanvas.parent.hero
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                            }
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            onHoverProgressChanged: requestPaint()
                            onMxChanged: requestPaint()
                            onMyChanged: requestPaint()
                            onPulseChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                if (parent.hero) {
                                    DivaPaint.paintWsPill(btnCanvas, 1.0, hoverProgress, pulse)
                                } else {
                                    DivaPaint.paintFacetPill(btnCanvas, hoverProgress, 6)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.sym
                            color: parent.hero ? "#ffffff" : (btnArea.containsMouse ? "#ffffff" : "#999999")
                            font.pixelSize: parent.hero ? 17 : 15
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: btnCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                            onPositionChanged: mouse => {
                                btnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                btnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                            }
                            onClicked: parent.activated()
                        }
                    }

                    MediaBtn {
                        sym: "⏮"
                        onActivated: if (mediaPopup.activePlayer) mediaPopup.activePlayer.previous()
                    }
                    MediaBtn {
                        width: 54
                        hero: mediaPopup.activePlayer && mediaPopup.activePlayer.isPlaying
                        sym: mediaPopup.activePlayer && mediaPopup.activePlayer.isPlaying ? "⏸" : "⏵"
                        onActivated: if (mediaPopup.activePlayer) mediaPopup.activePlayer.togglePlaying()
                    }
                    MediaBtn {
                        sym: "⏭"
                        onActivated: if (mediaPopup.activePlayer) mediaPopup.activePlayer.next()
                    }
                }

                Item {
                    id: playerSwitcher
                    visible: Mpris.players.values.length > 1
                    anchors { left: parent.left; right: parent.right; top: controlsRow.bottom; topMargin: 12; leftMargin: 14; rightMargin: 14 }
                    height: 24

                    Canvas {
                        id: playerCycleCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        property real mx: 0.5
                        property real my: 0.5
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onMxChanged: requestPaint()
                        onMyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(playerCycleCanvas, hoverProgress, 5)
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⇄"
                            color: playerCycleArea.containsMouse ? "#ffffff" : "#888888"
                            font.pixelSize: 11
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.identity : ""
                            color: playerCycleArea.containsMouse ? "#dddddd" : "#666666"
                            font.pixelSize: 10; font.family: "monospace"
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    MouseArea {
                        id: playerCycleArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: playerCycleCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            playerCycleCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            playerCycleCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            var players = Mpris.players.values
                            if (players.length < 2) return
                            var idx = players.indexOf(mediaPopup.activePlayer)
                            var next = players[(idx + 1) % players.length]
                            mediaPopup.preferredPlayer = next
                        }
                    }
                }
            }
        }
    }
}

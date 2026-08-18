import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "./DivaPaint.js" as DivaPaint

Window {
    id: mediaPopup
    property bool isOpen: false
    property var activePlayer: null
    property var preferredPlayer: null
    property var displayPlayer: activePlayer
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 260
    height: width + infoPanel.height + 2
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

    PanelBackground {
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

        Column {
            id: mediaContent
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            Rectangle {
                width: parent.width
                height: width
                color: "#111111"

                Image {
                    anchors.fill: parent
                    source: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: mediaPopup.displayPlayer && mediaPopup.displayPlayer.trackArtUrl !== ""
                }

                Rectangle {
                    visible: !mediaPopup.displayPlayer || mediaPopup.displayPlayer.trackArtUrl === ""
                    anchors.fill: parent
                    color: "#111111"
                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: "#39c5bb"
                        font.pixelSize: 48
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 48
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#cc1a1a1a" }
                    }
                }
            }

            Rectangle {
                id: infoPanel
                width: parent.width
                height: Mpris.players.values.length > 1
                    ? playerSwitcher.y + playerSwitcher.height + 10
                    : controlsRow.y + controlsRow.height + 16
                color: "#1a1a1a"

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
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 56 }
                    height: 26

                    Rectangle {
                        id: progressTrack
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: 4
                        radius: 2
                        color: "#2a2a2a"

                        Rectangle {
                            width: progressTrack.width * Math.max(0, Math.min(1, mediaPopup.displayPlayer && mediaPopup.displayPlayer.length > 0 ? mediaPopup.livePosition / mediaPopup.displayPlayer.length : 0))
                            height: parent.height
                            radius: parent.radius
                            color: "#39c5bb"
                            Behavior on width { NumberAnimation { duration: progressDragArea.pressed ? 0 : 400; easing.type: Easing.Linear } }
                        }
                    }

                    MouseArea {
                        id: progressDragArea
                        anchors { fill: parent }
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
                        anchors { left: parent.left; top: progressTrack.bottom; topMargin: 4 }
                        text: mediaPopup.formatTime(mediaPopup.livePosition)
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                    }

                    Text {
                        anchors { right: parent.right; top: progressTrack.bottom; topMargin: 4 }
                        text: mediaPopup.displayPlayer ? mediaPopup.formatTime(mediaPopup.displayPlayer.length) : "0:00"
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                }

                Row {
                    id: controlsRow
                    anchors { horizontalCenter: parent.horizontalCenter; top: progressArea.bottom; topMargin: 26 }
                    spacing: 12

                    component MediaBtn: Item {
                        width: 52
                        height: 36
                        property string sym: ""
                        signal activated()

                        Canvas {
                            id: btnCanvas
                            anchors.fill: parent
                            property real hoverProgress: 0.0
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onHoverProgressChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, hoverProgress, 6)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.sym
                            color: btnArea.containsMouse ? "#ffffff" : "#999999"
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: btnCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                            onClicked: parent.activated()
                        }
                    }

                    MediaBtn {
                        sym: "⏮"
                        onActivated: if (mediaPopup.activePlayer) mediaPopup.activePlayer.previous()
                    }
                    MediaBtn {
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
                    anchors { left: parent.left; right: parent.right; top: controlsRow.bottom; topMargin: 18; leftMargin: 14; rightMargin: 14 }
                    height: 28

                    Canvas {
                        id: playerCycleCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, hoverProgress, 5)
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

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Window {
    id: mediaPopup
    property bool isOpen: false
    property var activePlayer: null
    property var preferredPlayer: null
    property var displayPlayer: activePlayer
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 260
    height: 400
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

    Rectangle {
        id: mediaRect
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#39c5bb"
        border.width: 1

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
                width: parent.width
                height: parent.height - parent.width
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

                Row {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Mpris.players.values.length > 1 ? 46 : 16 }
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
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cut = 6, w = width, h = height, hp = hoverProgress
                                function drawShape() {
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0)
                                    ctx.lineTo(w,       0)
                                    ctx.lineTo(w,       h - cut)
                                    ctx.lineTo(w - cut, h)
                                    ctx.lineTo(0,       h)
                                    ctx.lineTo(0,       cut)
                                    ctx.closePath()
                                }
                                drawShape()
                                var base = ctx.createLinearGradient(0, 0, 0, h)
                                base.addColorStop(0,    "#3d3d3d")
                                base.addColorStop(0.08, "#2a2a2a")
                                base.addColorStop(0.5,  "#303030")
                                base.addColorStop(1.0,  "#3a3a3a")
                                ctx.fillStyle = base
                                ctx.fill()
                                if (hp > 0) {
                                    drawShape()
                                    var teal = ctx.createLinearGradient(0, 0, 0, h)
                                    teal.addColorStop(0,    "#80e0e0")
                                    teal.addColorStop(0.08, "#39c5bb")
                                    teal.addColorStop(0.5,  "#2a8a8a")
                                    teal.addColorStop(1.0,  "#3a6a6a")
                                    ctx.globalAlpha = hp
                                    ctx.fillStyle = teal
                                    ctx.fill()
                                    ctx.globalAlpha = 1.0
                                }
                                ctx.beginPath()
                                ctx.moveTo(cut, 0)
                                ctx.lineTo(w,   0)
                                ctx.lineTo(w,   h * 0.62)
                                ctx.lineTo(0,   h * 0.62)
                                ctx.lineTo(0,   cut)
                                ctx.closePath()
                                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                gloss.addColorStop(0, "rgba(255,255,255," + (0.15 + hp * 0.25) + ")")
                                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss
                                ctx.fill()
                                ctx.beginPath()
                                ctx.moveTo(cut, 0.5)
                                ctx.lineTo(w,   0.5)
                                ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"
                                ctx.lineWidth = 1
                                ctx.stroke()
                            }
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
                    visible: Mpris.players.values.length > 1
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10; leftMargin: 14; rightMargin: 14 }
                    height: 28

                    Canvas {
                        id: playerCycleCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 5, w = width, h = height, hp = hoverProgress
                            function drawShape() {
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                            }
                            drawShape()
                            var base = ctx.createLinearGradient(0, 0, 0, h)
                            base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
                            base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
                            ctx.fillStyle = base; ctx.fill()
                            if (hp > 0) {
                                drawShape()
                                var teal = ctx.createLinearGradient(0, 0, 0, h)
                                teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                            }
                            ctx.beginPath(); ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.10 + hp * 0.18) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                        }
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

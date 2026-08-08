import QtQuick
import Quickshell
import Quickshell.Widgets

Window {
    id: notifPopup
    property bool isOpen: false
    property var trackedNotifications
    property int notifCount: 0
    signal notifCountReset()
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 400
    visible: false

    function open(x, y) {
        notifPopup.x = x
        notifPopup.y = y
        isOpen = false
        visible = true
        notifOpenTimer.start()
    }

    function closePopup() { isOpen = false; notifCloseTimer.start() }
    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: notifOpenTimer; interval: 10; onTriggered: notifPopup.isOpen = true }
    Timer { id: notifCloseTimer; interval: 220; onTriggered: notifPopup.visible = false }

    Rectangle {
        id: notifRect
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#39c5bb"
        border.width: 1

        opacity: notifPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: notifPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: notifPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: notifRect.width / 2; origin.y: 0; xScale: notifRect.scaleVal; yScale: notifRect.scaleVal },
            Translate { y: notifRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 36

                Item {
                    id: clearAllBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    width: 58; height: 22
                    visible: notifPopup.notifCount > 0

                    Canvas {
                        id: clearAllCanvas
                        anchors.fill: parent
                        property real hoverProgress: 0.0
                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHoverProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 4, w = width, h = height, hp = hoverProgress
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
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "clear all"
                        color: clearAllArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 9; font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    MouseArea {
                        id: clearAllArea
                        anchors.fill: parent; hoverEnabled: true
                        onContainsMouseChanged: clearAllCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var notifs = notifPopup.trackedNotifications.values
                            for (var i = notifs.length - 1; i >= 0; i--) notifs[i].dismiss()
                            notifPopup.notifCountReset()
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 50
                visible: notifPopup.notifCount === 0
                Text {
                    anchors.centerIn: parent
                    text: "no notifications"
                    color: "#444444"; font.pixelSize: 11; font.family: "monospace"
                }
            }

            ListView {
                id: notifListView
                width: parent.width
                height: parent.height - 37
                clip: true
                visible: notifPopup.notifCount > 0
                model: notifPopup.trackedNotifications
                spacing: 3
                topMargin: 5
                bottomMargin: 5

                removeDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: notifDelegate
                    required property var modelData
                    width: notifListView.width
                    height: 66
                    clip: true

                    Item {
                        id: swipeItem
                        anchors { top: parent.top; bottom: parent.bottom }
                        width: parent.width - 8
                        x: swipeOffset + 4
                        opacity: Math.max(0, 1.0 - swipeOffset / 120)

                        property real swipeOffset: 0

                        Canvas {
                            id: notifCanvas
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
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss; ctx.fill()
                                ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                            }
                        }

                        Row {
                            anchors { left: parent.left; right: dismissItem.left; top: parent.top; bottom: parent.bottom; margins: 10; rightMargin: 4 }
                            spacing: 8

                            IconImage {
                                width: 22; height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.appIcon !== "" ? "image://icon/" + modelData.appIcon : ""
                                mipmap: true
                                visible: modelData.appIcon !== ""
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (modelData.appIcon !== "" ? 30 : 0)
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.summary
                                    color: notifItemArea.containsMouse ? "#ffffff" : "#d0d0d0"
                                    font.pixelSize: 12; font.family: "monospace"
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.body
                                    color: notifItemArea.containsMouse ? "#bbbbbb" : "#666666"
                                    font.pixelSize: 10; font.family: "monospace"
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    visible: modelData.body !== ""
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                            }
                        }

                        Item {
                            id: dismissItem
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                            width: 20; height: 20; z: 1

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: dismissArea.containsMouse ? "#ffffff" : "#555555"
                                font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: dismissArea
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: modelData.dismiss()
                            }
                        }

                        MouseArea {
                            id: notifItemArea
                            anchors.fill: parent; hoverEnabled: true
                            onContainsMouseChanged: notifCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        }
                    }

                    DragHandler {
                        id: notifSwipe
                        xAxis.enabled: true
                        xAxis.minimum: 0
                        yAxis.enabled: false
                        onTranslationChanged: if (active) swipeItem.swipeOffset = Math.max(0, translation.x)
                        onActiveChanged: {
                            if (!active) {
                                if (swipeItem.swipeOffset > 80) notifDelegate.modelData.dismiss()
                                else snapBackAnim.start()
                            }
                        }
                    }

                    NumberAnimation {
                        id: snapBackAnim
                        target: swipeItem
                        property: "swipeOffset"
                        to: 0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}

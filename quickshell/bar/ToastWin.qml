import QtQuick
import Quickshell
import Quickshell.Widgets
import "./DivaPaint.js" as DivaPaint

Window {
    id: toastWin
    property var notif: null
    property int stackIndex: 0
    property real anchorX: 0
    property real anchorY: 0
    property bool isOpen: false
    property bool closing: false

    signal dismissed()

    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 78

    property int stackGap: 8
    property real stackY: anchorY + stackIndex * (height + stackGap)
    Behavior on stackY { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    x: anchorX - width - 16
    y: stackY
    visible: true

    Component.onCompleted: toastOpenTimer.start()

    function requestClose() {
        if (toastWin.closing) return
        toastWin.closing = true
        toastWin.isOpen = false
        toastAutoClose.stop()
        toastHideTimer.start()
    }

    Timer { id: toastOpenTimer; interval: 10; onTriggered: toastWin.isOpen = true }
    Timer { id: toastAutoClose; interval: 4000; running: true; onTriggered: toastWin.requestClose() }
    Timer { id: toastHideTimer; interval: 220; onTriggered: toastWin.dismissed() }

    Item {
        id: toastAnimItem
        anchors.fill: parent

        opacity: toastWin.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: toastWin.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: toastWin.isOpen ? 0 : -10
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: toastAnimItem.width / 2; origin.y: 0; xScale: toastAnimItem.scaleVal; yScale: toastAnimItem.scaleVal },
            Translate { y: toastAnimItem.slideY }
        ]

        Item {
            id: toastSwipeItem
            width: parent.width
            height: parent.height
            x: swipeX
            opacity: Math.max(0, 1.0 - swipeX / 150)

            property real swipeX: 0

            Canvas {
                id: toastCanvas
                anchors.fill: parent
                onPaint: DivaPaint.paintFacetPill(toastCanvas, 0, 8)
            }

            Row {
                anchors { left: parent.left; right: toastCloseItem.left; top: parent.top; bottom: parent.bottom; margins: 12; rightMargin: 4 }
                spacing: 10

                IconImage {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    source: toastWin.notif && toastWin.notif.appIcon !== "" ? "image://icon/" + toastWin.notif.appIcon : ""
                    mipmap: true
                    visible: toastWin.notif && toastWin.notif.appIcon !== ""
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (toastWin.notif && toastWin.notif.appIcon !== "" ? 34 : 0)
                    spacing: 4

                    Text {
                        width: parent.width
                        text: toastWin.notif ? toastWin.notif.summary : ""
                        color: "#e0e0e0"
                        font.pixelSize: 13; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toastWin.notif ? toastWin.notif.body : ""
                        color: "#777777"
                        font.pixelSize: 11; font.family: "monospace"
                        elide: Text.ElideRight
                        visible: toastWin.notif && toastWin.notif.body !== ""
                    }
                }
            }

            GlowButton {
                id: toastCloseItem
                anchors { right: parent.right; top: parent.top; rightMargin: 6; topMargin: 6 }
                width: 20; height: 20
                cut: 4
                accent: DivaPaint.ACCENT_RED

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: toastCloseItem.hovered ? "#ffffff" : "#999999"
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                onClicked: toastWin.requestClose()
            }
        }

        DragHandler {
            id: toastSwipe
            xAxis.enabled: true
            yAxis.enabled: false
            onTranslationChanged: if (active) toastSwipeItem.swipeX = Math.max(0, translation.x)
            onActiveChanged: {
                if (!active) {
                    if (toastSwipeItem.swipeX > 80) {
                        if (toastWin.notif) toastWin.notif.dismiss()
                        toastWin.requestClose()
                    } else {
                        toastSnapBackAnim.start()
                    }
                }
            }
        }

        NumberAnimation {
            id: toastSnapBackAnim
            target: toastSwipeItem
            property: "swipeX"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
}

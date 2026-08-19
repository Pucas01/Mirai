import QtQuick
import Quickshell
import Quickshell.Widgets
import "./DivaPaint.js" as DivaPaint

Window {
    id: toastWin
    property bool isOpen: false
    property var currentNotif: null
    property var pendingNotif: null
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 78
    visible: false

    onPendingNotifChanged: {
        if (!pendingNotif) return
        currentNotif = pendingNotif
        toastSwipeItem.swipeX = 0
    }

    function show(x, y, notif) {
        pendingNotif = notif
        toastWin.x = x
        toastWin.y = y
        isOpen = false
        visible = true
        toastOpenTimer.start()
        toastAutoClose.restart()
    }

    Timer { id: toastOpenTimer; interval: 10; onTriggered: toastWin.isOpen = true }
    Timer { id: toastAutoClose; interval: 4000; onTriggered: { toastWin.isOpen = false; toastHideTimer.start() } }
    Timer { id: toastHideTimer; interval: 220; onTriggered: toastWin.visible = false }

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
                    source: toastWin.currentNotif && toastWin.currentNotif.appIcon !== "" ? "image://icon/" + toastWin.currentNotif.appIcon : ""
                    mipmap: true
                    visible: toastWin.currentNotif && toastWin.currentNotif.appIcon !== ""
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (toastWin.currentNotif && toastWin.currentNotif.appIcon !== "" ? 34 : 0)
                    spacing: 4

                    Text {
                        width: parent.width
                        text: toastWin.currentNotif ? toastWin.currentNotif.summary : ""
                        color: "#e0e0e0"
                        font.pixelSize: 13; font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: toastWin.currentNotif ? toastWin.currentNotif.body : ""
                        color: "#777777"
                        font.pixelSize: 11; font.family: "monospace"
                        elide: Text.ElideRight
                        visible: toastWin.currentNotif && toastWin.currentNotif.body !== ""
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

                onClicked: { toastWin.isOpen = false; toastHideTimer.start() }
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
                        if (toastWin.currentNotif) toastWin.currentNotif.dismiss()
                        toastWin.isOpen = false
                        toastHideTimer.start()
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

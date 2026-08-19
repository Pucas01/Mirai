import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: notifSection
    property var githubWin: null
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    anchors.fill: parent

    function reasonGlyph(reason) {
        if (reason === "mention") return "󰍡"
        if (reason === "review_requested") return "󰛄"
        if (reason === "author") return "󰐕"
        if (reason === "ci_activity") return "󰑮"
        if (reason === "assign") return "󰀉"
        return "󰂚"
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 24

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: githubWin ? githubWin.notifications.length + " notifications" : "0 notifications"
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }
    }

    ListView {
        id: notifList
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 12 }
        clip: true
        spacing: 6
        model: githubWin ? githubWin.notifications : []

        delegate: Item {
            id: notifRow
            required property var modelData
            width: notifList.width
            height: 46

            Canvas {
                id: notifRowCanvas
                anchors.fill: parent
                property real hp: 0.0
                property real mx: 0.5
                property real my: 0.5
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onMxChanged: requestPaint()
                onMyChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: DivaPaint.paintFacetPill(notifRowCanvas, notifRowCanvas.hp, 6)
            }

            Rectangle {
                visible: notifRow.modelData.unread
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
                width: 6; height: 6; radius: 3
                color: "#39c5bb"
            }

            Text {
                id: notifIcon
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: notifSection.reasonGlyph(notifRow.modelData.reason)
                color: "#999999"
                font.pixelSize: 13
            }

            Column {
                anchors { left: notifIcon.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 14 }
                spacing: 4

                Text {
                    width: parent.width
                    text: notifRow.modelData.title
                    color: notifRow.modelData.unread ? "#e0e0e0" : "#888888"
                    font.pixelSize: 11; font.family: "monospace"
                    elide: Text.ElideRight
                }

                Row {
                    spacing: 8
                    Text {
                        text: notifRow.modelData.repo
                        color: "#39c5bb"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                    Text {
                        text: "· " + githubWin.timeAgo(notifRow.modelData.updatedAt)
                        color: "#555555"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: notifRowCanvas.hp = containsMouse ? 1.0 : 0.0
                onPositionChanged: mouse => {
                    notifRowCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                    notifRowCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                }
                onClicked: githubWin.openUrl("https://github.com/" + notifRow.modelData.repo)
            }
        }
    }

    Text {
        anchors.centerIn: notifList
        visible: githubWin && !githubWin.notifsLoading && githubWin.notifications.length === 0
        text: "no notifications"
        color: "#444444"
        font.pixelSize: 12; font.family: "monospace"
    }

    Text {
        anchors.centerIn: notifList
        visible: githubWin && githubWin.notifsLoading && githubWin.notifications.length === 0
        text: "loading..."
        color: "#39c5bb"
        font.pixelSize: 12; font.family: "monospace"
    }
}

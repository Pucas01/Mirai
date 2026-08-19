import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: pullsSection
    property var githubWin: null
    property bool sectionActive: false
    property var prs: []
    property bool loading: false
    property string emptyText: "no pull requests"
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    anchors.fill: parent

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 24

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: pullsSection.prs.length + (pullsSection.prs.length === 1 ? " pull request" : " pull requests")
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }
    }

    ListView {
        id: prList
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 12 }
        clip: true
        spacing: 6
        model: pullsSection.prs

        delegate: Item {
            id: prRow
            required property var modelData
            width: prList.width
            height: 52

            Canvas {
                id: prRowCanvas
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
                onPaint: DivaPaint.paintFacetPill(prRowCanvas, prRowCanvas.hp, 7)
            }

            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 4

                Row {
                    spacing: 8
                    width: parent.width

                    Text {
                        text: prRow.modelData.isDraft ? "󰛢" : "󰀦"
                        color: prRow.modelData.isDraft ? "#999999" : "#6bff9e"
                        font.pixelSize: 12
                    }

                    Text {
                        width: parent.width - 60
                        text: prRow.modelData.title
                        color: "#e0e0e0"
                        font.pixelSize: 12; font.family: "monospace"
                        elide: Text.ElideRight
                    }
                }

                Row {
                    spacing: 8
                    Text {
                        text: prRow.modelData.repository.nameWithOwner + " #" + prRow.modelData.number
                        color: "#39c5bb"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                    Text {
                        text: "· " + githubWin.timeAgo(prRow.modelData.updatedAt)
                        color: "#555555"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: prRowCanvas.hp = containsMouse ? 1.0 : 0.0
                onPositionChanged: mouse => {
                    prRowCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                    prRowCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                }
                onClicked: githubWin.openUrl(prRow.modelData.url)
            }
        }
    }

    Text {
        anchors.centerIn: prList
        visible: !pullsSection.loading && pullsSection.prs.length === 0
        text: pullsSection.emptyText
        color: "#444444"
        font.pixelSize: 12; font.family: "monospace"
    }

    Text {
        anchors.centerIn: prList
        visible: pullsSection.loading && pullsSection.prs.length === 0
        text: "loading..."
        color: "#39c5bb"
        font.pixelSize: 12; font.family: "monospace"
    }
}

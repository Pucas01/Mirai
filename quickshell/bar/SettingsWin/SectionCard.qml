import QtQuick

Item {
    id: card
    default property alias content: cardBody.children
    property alias headerAction: actionSlot.children
    property string title: ""
    property string path: ""
    property string status: ""
    property color statusColor: "#444444"
    property int cut: 8
    signal folderClicked()
    width: parent ? parent.width - parent.leftPadding - parent.rightPadding : 0
    height: cardHeader.height + cardBody.height + 16

    Canvas {
        id: cardCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height, cut = card.cut
            ctx.clearRect(0, 0, w, h)

            function drawShape() {
                ctx.beginPath()
                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
            }

            drawShape()
            ctx.fillStyle = "#1c1c1c"
            ctx.fill()

            ctx.beginPath()
            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.4)
            ctx.lineTo(0, h * 0.4); ctx.lineTo(0, cut); ctx.closePath()
            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.4)
            gloss.addColorStop(0, "rgba(255,255,255,0.05)")
            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
            ctx.fillStyle = gloss; ctx.fill()

            drawShape()
            ctx.strokeStyle = "#3a3a3a"
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    Item {
        id: cardHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 34

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
            text: card.title
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }

        Text {
            anchors { right: actionSlot.children.length > 0 ? actionSlot.left : (cardFolderBtn.visible ? cardFolderBtn.left : parent.right); verticalCenter: parent.verticalCenter; rightMargin: 10 }
            text: card.status
            color: card.statusColor
            font.pixelSize: 9; font.family: "monospace"
            elide: Text.ElideMiddle
        }

        Row {
            id: actionSlot
            anchors { right: cardFolderBtn.visible ? cardFolderBtn.left : parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            spacing: 6
        }

        FolderBtn {
            id: cardFolderBtn
            visible: card.path.length > 0
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            onClicked: card.folderClicked()
        }
    }

    Column {
        id: cardBody
        anchors { top: cardHeader.bottom; left: parent.left; right: parent.right; topMargin: 4 }
        height: childrenRect.height
    }
}

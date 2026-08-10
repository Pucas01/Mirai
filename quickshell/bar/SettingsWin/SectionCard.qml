import QtQuick

Rectangle {
    id: card
    default property alias content: cardBody.children
    property alias headerAction: actionSlot.children
    property string title: ""
    property string path: ""
    property string status: ""
    property color statusColor: "#444444"
    signal folderClicked()
    width: parent ? parent.width - parent.leftPadding - parent.rightPadding : 0
    color: "#1e1e1e"
    border.color: "#2a2a2a"
    border.width: 1
    height: cardHeader.height + cardBody.height + 16

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

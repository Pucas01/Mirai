import QtQuick

Item {
    id: diffViewer
    property var reposWin: null

    readonly property var diffLines: {
        if (!reposWin || reposWin.diffText === "") return []
        return reposWin.diffText.split("\n")
    }

    function lineColor(line) {
        if (line.indexOf("+++") === 0 || line.indexOf("---") === 0) return "#888888"
        if (line.indexOf("@@") === 0) return "#39c5bb"
        if (line.indexOf("diff --git") === 0 || line.indexOf("index ") === 0) return "#666666"
        if (line[0] === "+") return "#7ad67a"
        if (line[0] === "-") return "#e07a7a"
        return "#aaaaaa"
    }

    function lineBg(line) {
        if (line[0] === "+" && line.indexOf("+++") !== 0) return "#0d1f0d"
        if (line[0] === "-" && line.indexOf("---") !== 0) return "#1f0d0d"
        return "transparent"
    }

    Item {
        id: diffHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 22
        visible: diffViewer.reposWin && diffViewer.reposWin.selectedFile !== ""

        Text {
            anchors.left: parent.left
            text: diffViewer.reposWin ? diffViewer.reposWin.selectedFile : ""
            color: "#999999"
            font.pixelSize: 10; font.family: "monospace"
            elide: Text.ElideLeft
            width: parent.width
        }
    }

    Rectangle {
        anchors { top: diffHeader.visible ? diffHeader.bottom : parent.top; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: diffHeader.visible ? 6 : 0 }
        color: "#141414"
        border.color: "#2a2a2a"
        border.width: 1

        Flickable {
            id: diffFlick
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            contentWidth: Math.max(width, diffCol.implicitWidth + 16)
            contentHeight: diffCol.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: diffCol
                x: 8
                y: 6
                width: Math.max(diffFlick.width - 16, implicitWidth)
                Repeater {
                    model: diffViewer.diffLines
                    delegate: Item {
                        id: diffLineRow
                        required property var modelData
                        required property int index
                        width: Math.max(diffCol.width, diffLineText.implicitWidth)
                        height: diffLineText.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -8
                            anchors.rightMargin: -8
                            color: diffViewer.lineBg(diffLineRow.modelData)
                        }

                        Text {
                            id: diffLineText
                            text: diffLineRow.modelData.length > 0 ? diffLineRow.modelData : " "
                            color: diffViewer.lineColor(diffLineRow.modelData)
                            font.pixelSize: 10; font.family: "monospace"
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: diffViewer.reposWin && diffViewer.reposWin.diffLoading
            text: "loading diff..."
            color: "#39c5bb"
            font.pixelSize: 11; font.family: "monospace"
        }

        Text {
            anchors.centerIn: parent
            visible: diffViewer.reposWin && !diffViewer.reposWin.diffLoading && diffViewer.reposWin.selectedFile === ""
            text: "select a file to view its diff"
            color: "#444444"
            font.pixelSize: 11; font.family: "monospace"
        }
    }
}

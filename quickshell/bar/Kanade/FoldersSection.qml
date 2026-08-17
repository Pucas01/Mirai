import QtQuick

Item {
    id: foldersSection
    property var kanadeWin: null
    property bool sectionActive: false
    visible: sectionActive
    anchors.fill: parent

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 24
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "library folders"
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }
    }

    Column {
        id: folderList
        anchors { top: header.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 6 }
        spacing: 6

        Repeater {
            model: kanadeWin ? kanadeWin.libraryRoots : []
            delegate: Rectangle {
                required property var modelData
                width: folderList.width
                height: 36
                color: "#1e1e1e"
                border.color: "#2a2a2a"
                border.width: 1

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: removeBtn.left; leftMargin: 12; rightMargin: 8 }
                    text: modelData
                    color: "#cccccc"
                    font.pixelSize: 11; font.family: "monospace"
                    elide: Text.ElideMiddle
                }

                Item {
                    id: removeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    width: 24; height: 20

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: removeArea.containsMouse ? "#ff6b6b" : "#666666"
                        font.pixelSize: 10
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: kanadeWin.removeRoot(modelData)
                    }
                }
            }
        }
    }

    Item {
        anchors { top: folderList.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 10 }
        height: 30

        Item {
            anchors { left: parent.left; right: addBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            height: 28

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 6, w = width, h = height
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                    ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                    ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                    ctx.fillStyle = "#242424"; ctx.fill()
                    ctx.strokeStyle = "#2e2e2e"; ctx.lineWidth = 1; ctx.stroke()
                }
            }

            TextInput {
                id: newFolderInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                color: "#e0e0e0"
                font.pixelSize: 11; font.family: "monospace"
                selectByMouse: true
                text: kanadeWin ? kanadeWin.homeDir + "/Music" : ""
                Keys.onReturnPressed: {
                    kanadeWin.addRoot(newFolderInput.text)
                    kanadeWin.rescan()
                }
            }
        }

        Item {
            id: addBtn
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 70; height: 28

            Canvas {
                id: addCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 6, w = width, h = height, hp = addCanvas.hp
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
                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                }
            }
            Text {
                anchors.centerIn: parent
                text: "add"
                color: addArea.containsMouse ? "#ffffff" : "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: addCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: {
                    kanadeWin.addRoot(newFolderInput.text)
                    kanadeWin.rescan()
                }
            }
        }
    }
}

import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: sidebar
    property var reposWin: null

    Rectangle {
        anchors.fill: parent
        color: "#161616"
    }

    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1
        color: "#2a2a2a"
    }

    Item {
        id: addRow
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
        height: 30

        Canvas {
            id: addCanvas
            anchors.fill: parent
            property real hp: 0.0
            property real mx: 0.5
            property real my: 0.5
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: DivaPaint.paintFacetPill(addCanvas, addCanvas.hp, 5)
        }

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text { text: "+"; color: "#39c5bb"; font.pixelSize: 13; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "add repository"; color: "#cccccc"; font.pixelSize: 10; font.family: "monospace"; anchors.verticalCenter: parent.verticalCenter }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: addCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: sidebar.reposWin.pickFolder()
        }
    }

    ListView {
        id: repoTree
        anchors { top: addRow.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 6; leftMargin: 6; rightMargin: 6; bottomMargin: 8 }
        clip: true
        spacing: 2
        model: sidebar.reposWin ? sidebar.reposWin.savedRepos : []

        delegate: Column {
            id: repoBlock
            required property var modelData
            width: repoTree.width
            readonly property bool isActive: sidebar.reposWin.activeRepoRoot === modelData.path
            readonly property bool open: !!sidebar.reposWin.expandedRepos[modelData.path]
            readonly property var subs: sidebar.reposWin.submoduleCache[modelData.path] || []

            Item {
                id: repoRow
                width: parent.width
                height: 34

                Canvas {
                    id: repoRowCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    property real mx: 0.5
                    property real my: 0.5
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections {
                        target: repoBlock
                        function onIsActiveChanged() { repoRowCanvas.requestPaint() }
                    }
                    onPaint: DivaPaint.paintFacetPill(repoRowCanvas, Math.max(hp, repoBlock.isActive ? 1.0 : 0.0), 5)
                }

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 6; right: removeBtn.left; rightMargin: 4 }
                    spacing: 6

                    Text {
                        id: chevron
                        text: "󰅂"
                        color: "#39c5bb"
                        font.pixelSize: 10
                        rotation: repoBlock.open ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebar.reposWin.toggleRepoExpanded(repoBlock.modelData.path)
                        }
                    }
                    Text {
                        text: "󰊢"
                        color: repoBlock.isActive ? "#ffffff" : "#888888"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: parent.width - 40
                        text: repoBlock.modelData.name
                        color: repoBlock.isActive ? "#ffffff" : "#cccccc"
                        font.pixelSize: 11; font.family: "monospace"
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    id: removeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    text: "✕"
                    color: removeArea.containsMouse ? "#e05050" : "#444444"
                    font.pixelSize: 10
                    visible: repoRowArea.containsMouse || removeArea.containsMouse

                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebar.reposWin.removeRepo(repoBlock.modelData.path)
                    }
                }

                MouseArea {
                    id: repoRowArea
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: repoRowCanvas.hp = containsMouse ? 1.0 : 0.0
                    onClicked: sidebar.reposWin.openRepo(repoBlock.modelData.path)
                }
            }

            Item {
                id: subContainer
                width: parent.width
                height: repoBlock.open ? subColumn.implicitHeight : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    id: subColumn
                    width: parent.width
                    Repeater {
                        model: repoBlock.subs
                        delegate: Item {
                            id: subRow
                            required property var modelData
                            width: subColumn.width
                            height: 26
                            readonly property bool isActive: sidebar.reposWin.activePath === (repoBlock.modelData.path + "/" + modelData.path)

                            Canvas {
                                id: subCanvas
                                anchors.fill: parent
                                property real hp: 0.0
                                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHpChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: subRow
                                    function onIsActiveChanged() { subCanvas.requestPaint() }
                                }
                                onPaint: DivaPaint.paintFacetPill(subCanvas, Math.max(hp, subRow.isActive ? 1.0 : 0.0), 4)
                            }

                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 22 }
                                spacing: 6
                                Text {
                                    text: subRow.modelData.notInitialized ? "󰉒" : "󰈔"
                                    color: subRow.modelData.notInitialized ? "#666666" : (subRow.isActive ? "#ffffff" : "#777777")
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 140
                                    text: subRow.modelData.path.split("/").pop()
                                    color: subRow.isActive ? "#ffffff" : "#999999"
                                    font.pixelSize: 10; font.family: "monospace"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    visible: subRow.modelData.dirty
                                    width: 5; height: 5; radius: 2.5
                                    color: "#e0a84a"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: subCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    if (subRow.modelData.notInitialized) {
                                        sidebar.reposWin.updateSubmodule(subRow.modelData.path)
                                    } else {
                                        sidebar.reposWin.openSubmodule(repoBlock.modelData.path, subRow.modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: workspace
    property var reposWin: null

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 28

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text: "󰘬"
                color: "#39c5bb"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: workspace.reposWin.branchName || "..."
                color: "#e0e0e0"
                font.pixelSize: 12; font.family: "monospace"; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                visible: workspace.reposWin.aheadCount > 0 || workspace.reposWin.behindCount > 0
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text { visible: workspace.reposWin.aheadCount > 0; text: "↑" + workspace.reposWin.aheadCount; color: "#39c5bb"; font.pixelSize: 10; font.family: "monospace" }
                Text { visible: workspace.reposWin.behindCount > 0; text: "↓" + workspace.reposWin.behindCount; color: "#e0a84a"; font.pixelSize: 10; font.family: "monospace" }
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6

            component ActionBtn: Item {
                id: actionBtn
                property string label: ""
                property bool busy: false
                property var accent: DivaPaint.ACCENT_TEAL
                signal clicked()
                width: btnText.implicitWidth + 22
                height: 24

                Canvas {
                    id: actionCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(actionCanvas, actionCanvas.hp, 4, actionBtn.accent)
                }

                Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: actionBtn.busy ? "..." : actionBtn.label
                    color: actionArea.containsMouse ? "#ffffff" : "#bbbbbb"
                    font.pixelSize: 10; font.family: "monospace"
                }

                MouseArea {
                    id: actionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: actionCanvas.hp = containsMouse ? 1.0 : 0.0
                    onClicked: actionBtn.clicked()
                }
            }

            ActionBtn { label: "terminal"; onClicked: workspace.reposWin.openInTerminal(workspace.reposWin.activePath) }
            ActionBtn { label: "code"; onClicked: workspace.reposWin.openInEditor(workspace.reposWin.activePath) }
            ActionBtn { label: "pull"; busy: workspace.reposWin.pulling; onClicked: workspace.reposWin.doPull() }
            ActionBtn { label: "push"; busy: workspace.reposWin.pushing; onClicked: workspace.reposWin.doPush() }
        }
    }

    Text {
        anchors { top: header.bottom; left: parent.left; leftMargin: 14; topMargin: 2 }
        visible: workspace.reposWin.gitOpError !== ""
        text: workspace.reposWin.gitOpError
        color: "#e05050"
        font.pixelSize: 9; font.family: "monospace"
        width: parent.width - 28
        wrapMode: Text.Wrap
    }

    Row {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 10; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        spacing: 12

        Column {
            id: filesCol
            width: 260
            height: parent.height
            spacing: 8

            Item {
                width: parent.width
                height: 22
                Text {
                    anchors.left: parent.left
                    text: workspace.reposWin.changedFiles.length + " changed file" + (workspace.reposWin.changedFiles.length === 1 ? "" : "s")
                    color: "#888888"
                    font.pixelSize: 10; font.family: "monospace"; font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    visible: workspace.reposWin.changedFiles.length > 0
                    text: "stage all"
                    color: stageAllArea.containsMouse ? "#39c5bb" : "#666666"
                    font.pixelSize: 9; font.family: "monospace"
                    MouseArea { id: stageAllArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: workspace.reposWin.stageAll() }
                }
            }

            ListView {
                id: fileList
                width: parent.width
                height: parent.height - 22 - commitBox.height - parent.spacing * 2
                clip: true
                spacing: 2
                model: workspace.reposWin.changedFiles

                delegate: Item {
                    id: fileRow
                    required property var modelData
                    width: fileList.width
                    height: 28
                    readonly property bool isSelected: workspace.reposWin.selectedFile === modelData.path

                    Canvas {
                        id: fileRowCanvas
                        anchors.fill: parent
                        property real hp: 0.0
                        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHpChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections {
                            target: fileRow
                            function onIsSelectedChanged() { fileRowCanvas.requestPaint() }
                        }
                        onPaint: DivaPaint.paintFacetPill(fileRowCanvas, Math.max(hp, fileRow.isSelected ? 1.0 : 0.0), 4)
                    }

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8; right: stageBtn.left; rightMargin: 4 }
                        spacing: 6
                        Text {
                            text: fileRow.modelData.statusCode === "??" ? "U" : (fileRow.modelData.staged ? "S" : "M")
                            color: fileRow.modelData.statusCode === "??" ? "#39c5bb" : (fileRow.modelData.staged ? "#7ad67a" : "#e0a84a")
                            font.pixelSize: 9; font.family: "monospace"; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: parent.width - 16
                            text: fileRow.modelData.path.split("/").pop()
                            color: fileRow.isSelected ? "#ffffff" : "#cccccc"
                            font.pixelSize: 10; font.family: "monospace"
                            elide: Text.ElideLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        id: stageBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                        text: fileRow.modelData.staged ? "−" : "+"
                        color: stageBtnArea.containsMouse ? "#39c5bb" : "#666666"
                        font.pixelSize: 12; font.bold: true

                        MouseArea {
                            id: stageBtnArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (fileRow.modelData.staged) workspace.reposWin.unstageFile(fileRow.modelData.path)
                                else workspace.reposWin.stageFile(fileRow.modelData.path)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: fileRowCanvas.hp = containsMouse ? 1.0 : 0.0
                        onClicked: workspace.reposWin.selectFile(fileRow.modelData)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: workspace.reposWin.changedFiles.length === 0 && !workspace.reposWin.statusLoading
                text: "no changes"
                color: "#444444"
                font.pixelSize: 10; font.family: "monospace"
            }

            Column {
                id: commitBox
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 60
                    color: "#161616"
                    border.color: commitInput.activeFocus ? "#1f8a82" : "#2a2a2a"
                    border.width: 1

                    TextEdit {
                        id: commitInput
                        anchors.fill: parent
                        anchors.margins: 8
                        color: "#e0e0e0"
                        font.pixelSize: 10; font.family: "monospace"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        onTextChanged: workspace.reposWin.commitMessage = text

                        Text {
                            anchors.fill: parent
                            visible: commitInput.text === "" && !commitInput.activeFocus
                            text: "commit message..."
                            color: "#444444"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 26

                    Canvas {
                        id: commitCanvas
                        anchors.fill: parent
                        property real hp: 0.0
                        readonly property bool enabled_: workspace.reposWin.commitMessage.trim() !== "" && workspace.reposWin.changedFiles.some(function(f) { return f.staged })
                        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHpChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(commitCanvas, commitCanvas.enabled_ ? commitCanvas.hp : 0, 4)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: workspace.reposWin.committing ? "committing..." : "commit"
                        color: commitCanvas.enabled_ ? (commitArea.containsMouse ? "#ffffff" : "#bbbbbb") : "#444444"
                        font.pixelSize: 10; font.family: "monospace"
                    }

                    MouseArea {
                        id: commitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: commitCanvas.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onContainsMouseChanged: commitCanvas.hp = containsMouse ? 1.0 : 0.0
                        onClicked: if (commitCanvas.enabled_) workspace.reposWin.doCommit()
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: "#2a2a2a"
        }

        DiffViewer {
            width: parent.width - filesCol.width - 13
            height: parent.height
            reposWin: workspace.reposWin
        }
    }
}

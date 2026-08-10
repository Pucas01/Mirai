import QtQuick
import Quickshell.Io

Item {
    id: aboutSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: aboutSection.slideY }

    Process {
        id: openRepoProc
        command: ["xdg-open", "https://github.com/Pucas01/Mirai"]
        running: false
    }

    Item {
        id: aboutHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
            label: "about"
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -16
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Mirai"
            color: "#39c5bb"
            font.pixelSize: 34; font.bold: true; font.family: "monospace"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "My personal quickshell, i like it very much"
            color: "#999999"
            font.pixelSize: 11; font.family: "monospace"
        }

        Item { width: 1; height: 10 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "built by Pucas01"
            color: "#666666"
            font.pixelSize: 10; font.family: "monospace"
        }

        Text {
            id: repoLinkText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "github.com/Pucas01/Mirai"
            color: repoLinkArea.containsMouse ? "#80e0e0" : "#39c5bb"
            font.pixelSize: 10; font.family: "monospace"
            font.underline: repoLinkArea.containsMouse
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea {
                id: repoLinkArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { openRepoProc.running = false; openRepoProc.running = true }
            }
        }

        Item { width: 1; height: 12 }

        Item {
            id: updateArea
            anchors.horizontalCenter: parent.horizontalCenter
            width: updateColumn.width
            height: updateColumn.height

            Column {
                id: updateColumn
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: aboutSection.settingsWin.updateApplying
                    text: "updating..."
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: aboutSection.settingsWin.updateError !== ""
                    text: aboutSection.settingsWin.updateError
                    color: "#ff6b6b"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Item {
                    id: updateBtn
                    visible: aboutSection.settingsWin.updateAvailable && !aboutSection.settingsWin.updateApplying
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: updateBtnRow.width + 24
                    height: 28

                    Canvas {
                        id: updateBtnCanvas
                        anchors.fill: parent
                        property real hp: 0.0
                        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHpChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 6, w = width, h = height, hp = updateBtnCanvas.hp
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
                            drawShape()
                            var teal = ctx.createLinearGradient(0, 0, 0, h)
                            teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                            teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                            ctx.globalAlpha = 0.7 + hp * 0.3; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.18 + hp * 0.2) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = "#c0f4f4"; ctx.lineWidth = 1; ctx.stroke()
                        }
                    }

                    Row {
                        id: updateBtnRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            visible: !aboutSection.settingsWin.updateApplying
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ff4444"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "update available (" + aboutSection.settingsWin.updateCommitsBehind + " commit" + (aboutSection.settingsWin.updateCommitsBehind === 1 ? "" : "s") + ")"
                            color: "#ffffff"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: updateBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                        onClicked: aboutSection.settingsWin.applyUpdate()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !aboutSection.settingsWin.updateAvailable && !aboutSection.settingsWin.updateApplying && !aboutSection.settingsWin.updateChecking && aboutSection.settingsWin.updateError === ""
                    text: "up to date"
                    color: "#555555"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Text {
                    id: checkNowText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !aboutSection.settingsWin.updateApplying
                    text: aboutSection.settingsWin.updateChecking ? "checking..." : "check for updates"
                    color: aboutSection.settingsWin.updateChecking ? "#555555" : (checkNowArea.containsMouse ? "#80e0e0" : "#39c5bb")
                    font.pixelSize: 9; font.family: "monospace"
                    font.underline: !aboutSection.settingsWin.updateChecking && checkNowArea.containsMouse
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: checkNowArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: aboutSection.settingsWin.updateChecking ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!aboutSection.settingsWin.updateChecking) aboutSection.settingsWin.checkForUpdate()
                    }
                }
            }
        }
    }
}

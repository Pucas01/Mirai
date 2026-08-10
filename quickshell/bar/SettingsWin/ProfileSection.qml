import QtQuick
import Qt.labs.folderlistmodel

Item {
    id: profileSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: profileSection.slideY }

    function refreshPfpModel() {
        pfpModel.folder = ""
        pfpModel.folder = Qt.binding(function() { return "file://" + settingsWin.pfpDir })
    }

    function refreshStartIconModel() {
        startIconModel.folder = ""
        startIconModel.folder = Qt.binding(function() { return "file://" + settingsWin.startIconDir })
    }

    Item {
        id: pfpHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: pfpDirText.left; rightMargin: 10 }
            label: "profile"
        }

        Text {
            id: pfpDirText
            anchors { right: openPfpFolderBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            text: settingsWin.pfpDir
            color: "#444444"
            font.pixelSize: 9; font.family: "monospace"
        }

        Item {
            id: openPfpFolderBtn
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            width: 28; height: 22

            Canvas {
                id: openPfpFolderCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 4, w = width, h = height, hp = openPfpFolderCanvas.hp
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
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss; ctx.fill()
                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰝰"
                color: openPfpFolderArea.containsMouse ? "#ffffff" : "#999999"
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: openPfpFolderArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: openPfpFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: {
                    settingsWin.ensurePfpDirProc.running = false
                    settingsWin.ensurePfpDirProc.running = true
                    settingsWin.openPfpDirProc.running = false
                    settingsWin.openPfpDirProc.running = true
                }
            }
        }
    }

    Item {
        id: startIconRow
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 108

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: "#2a2a2a"
        }

        Text {
            anchors { left: parent.left; top: parent.top; topMargin: 12; leftMargin: 16 }
            text: "start button icon"
            color: "#999999"
            font.pixelSize: 11; font.family: "monospace"
        }

        Text {
            anchors { right: startIconFolderBtn.left; top: parent.top; topMargin: 12; rightMargin: 10 }
            text: settingsWin.startIconDir
            color: "#444444"
            font.pixelSize: 9; font.family: "monospace"
        }

        Item {
            id: startIconFolderBtn
            anchors { right: parent.right; top: parent.top; topMargin: 8; rightMargin: 16 }
            width: 28; height: 22

            Canvas {
                id: startIconFolderCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 4, w = width, h = height, hp = startIconFolderCanvas.hp
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
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss; ctx.fill()
                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰝰"
                color: startIconFolderArea.containsMouse ? "#ffffff" : "#999999"
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: startIconFolderArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: startIconFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: {
                    settingsWin.ensureStartIconDirProc.running = false
                    settingsWin.ensureStartIconDirProc.running = true
                    settingsWin.openStartIconDirProc.running = false
                    settingsWin.openStartIconDirProc.running = true
                }
            }
        }

        FolderListModel {
            id: startIconModel
            folder: "file://" + settingsWin.startIconDir
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.svg", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.SVG"]
            showDirs: false
        }

        ListView {
            id: startIconListView
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top; topMargin: 36; bottomMargin: 12; leftMargin: 16; rightMargin: 16 }
            orientation: ListView.Horizontal
            spacing: 8
            clip: true

            model: startIconModel
            delegate: Item {
                id: startIconTile
                width: 60; height: 60
                readonly property bool selected: settingsWin.startIconPath === model.filePath

                Rectangle {
                    anchors.fill: parent
                    color: "#242424"
                }

                Image {
                    anchors { fill: parent; margins: 8 }
                    source: "file://" + model.filePath
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: startIconTile.selected ? "#39c5bb" : "#2a2a2a"
                    border.width: startIconTile.selected ? 2 : 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsWin.setStartIconImage(model.filePath)
                }
            }

            header: Item {
                width: 60; height: 60
                readonly property bool selected: settingsWin.startIconPath === ""

                Rectangle {
                    anchors.fill: parent
                    color: "#242424"
                }

                Text {
                    anchors.centerIn: parent
                    text: settingsWin.defaultStartIcon
                    color: "#39c5bb"
                    font.pixelSize: 20
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: parent.selected ? "#39c5bb" : "#2a2a2a"
                    border.width: parent.selected ? 2 : 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsWin.setStartIconImage("")
                }
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 70 }
                visible: startIconModel.count === 0
                text: "no images found in " + settingsWin.startIconDir
                color: "#444444"
                font.pixelSize: 10; font.family: "monospace"
            }
        }
    }

    FolderListModel {
        id: pfpModel
        folder: "file://" + settingsWin.pfpDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
        showDirs: false
    }

    GridView {
        anchors { top: pfpHeader.bottom; bottom: startIconRow.top; left: parent.left; right: parent.right; margins: 10 }
        cellWidth: 110; cellHeight: 110
        clip: true
        model: pfpModel

        delegate: Item {
            id: pfpTileRoot
            width: 110; height: 110
            readonly property bool selected: settingsWin.pfpPath === model.filePath

            Item {
                id: pfpTile
                anchors.fill: parent
                anchors.margins: 8

                Rectangle {
                    anchors.fill: parent
                    color: "#242424"
                }

                Image {
                    id: pfpTileImage
                    visible: false
                    source: "file://" + model.filePath
                    asynchronous: true
                    onStatusChanged: if (status === Image.Ready) pfpTileCanvas.requestPaint()
                }

                Canvas {
                    id: pfpTileCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (pfpTileImage.status !== Image.Ready) return
                        var iw = pfpTileImage.sourceSize.width, ih = pfpTileImage.sourceSize.height
                        if (iw <= 0 || ih <= 0) return
                        var targetAspect = width / height
                        var srcAspect = iw / ih
                        var sx, sy, sw, sh
                        if (srcAspect > targetAspect) {
                            sh = ih; sw = ih * targetAspect; sx = (iw - sw) / 2; sy = 0
                        } else {
                            sw = iw; sh = iw / targetAspect; sx = 0; sy = (ih - sh) / 2
                        }
                        ctx.save()
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2)
                        ctx.closePath()
                        ctx.clip()
                        ctx.drawImage(pfpTileImage, sx, sy, sw, sh, 0, 0, width, height)
                        ctx.restore()
                    }
                }
            }

            Rectangle {
                z: 10
                anchors.fill: pfpTile
                radius: width / 2
                color: "transparent"
                border.color: pfpTileRoot.selected ? "#39c5bb" : "#2a2a2a"
                border.width: pfpTileRoot.selected ? 2 : 1
            }

            MouseArea {
                anchors.fill: pfpTile
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsWin.setPfp(model.filePath)
            }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: pfpHeader.bottom; bottom: startIconRow.top }
        verticalAlignment: Text.AlignVCenter
        visible: pfpModel.count === 0
        text: "no images found\n" + settingsWin.pfpDir
        color: "#444444"
        font.pixelSize: 11; font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
    }
}

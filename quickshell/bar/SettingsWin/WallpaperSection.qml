import QtQuick
import Quickshell.Io
import Qt.labs.folderlistmodel

Item {
    id: wallpaperSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: wallpaperSection.slideY }

    function ensureDir() {
        ensureWallpaperDirProc.running = false
        ensureWallpaperDirProc.running = true
    }

    Process {
        id: wallpaperProc
        command: ["awww", "img", settingsWin.appliedWallpaper]
        running: false
    }

    Process {
        id: ensureWallpaperDirProc
        command: ["mkdir", "-p", settingsWin.wallpaperDir]
        running: false
        onExited: {
            wallpaperModel.folder = ""
            wallpaperModel.folder = Qt.binding(function() { return "file://" + settingsWin.wallpaperDir })
        }
    }

    Process {
        id: openWallpaperDirProc
        command: ["nautilus", settingsWin.wallpaperDir]
        running: false
    }

    Item {
        id: wpHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: wpDirText.left; rightMargin: 10 }
            label: "wallpaper"
        }

        Text {
            id: wpDirText
            anchors { right: openFolderBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            text: settingsWin.wallpaperDir
            color: "#444444"
            font.pixelSize: 9; font.family: "monospace"
        }

        Item {
            id: openFolderBtn
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            width: 28; height: 22

            Canvas {
                id: openFolderCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 4, w = width, h = height, hp = openFolderCanvas.hp
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
                color: openFolderArea.containsMouse ? "#ffffff" : "#999999"
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: openFolderArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: openFolderCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: {
                    ensureWallpaperDirProc.running = false
                    ensureWallpaperDirProc.running = true
                    openWallpaperDirProc.running = false
                    openWallpaperDirProc.running = true
                }
            }
        }
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + settingsWin.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
        showDirs: false
    }

    GridView {
        anchors { top: wpHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 10 }
        cellWidth: 160; cellHeight: 110
        clip: true
        model: wallpaperModel

        delegate: Item {
            width: 160; height: 110

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                color: "#242424"
                border.color: settingsWin.appliedWallpaper === model.filePath ? "#39c5bb" : "#2a2a2a"
                border.width: settingsWin.appliedWallpaper === model.filePath ? 2 : 1
                clip: true

                Image {
                    anchors { fill: parent; bottomMargin: 20 }
                    source: "file://" + model.filePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 20
                    color: "#99000000"

                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 4; rightMargin: 4 }
                        text: model.fileName
                        color: "#cccccc"
                        font.pixelSize: 9; font.family: "monospace"
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        settingsWin.appliedWallpaper = model.filePath
                        wallpaperProc.running = false
                        wallpaperProc.running = true
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: wallpaperModel.count === 0
        text: "no images found\n" + settingsWin.wallpaperDir
        color: "#444444"
        font.pixelSize: 11; font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
    }
}

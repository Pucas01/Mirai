import QtQuick
import Quickshell.Io
import Qt.labs.folderlistmodel
import "../DivaPaint.js" as DivaPaint

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
        command: ["awww", "img", settingsWin.appliedWallpaper,
            "--transition-type", "grow",
            "--transition-pos", "center",
            "--transition-duration", "0.8"]
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
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: parent.right; rightMargin: 16 }
            label: "wallpaper"
        }
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + settingsWin.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
        showDirs: false
    }

    SectionCard {
        anchors { top: wpHeader.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; topMargin: 4 }
        width: parent.width - 32
        title: "wallpapers"
        path: settingsWin.wallpaperDir
        status: settingsWin.appliedWallpaper !== "" ? settingsWin.appliedWallpaper.split("/").pop() : "none selected"
        statusColor: settingsWin.appliedWallpaper !== "" ? "#39c5bb" : "#444444"
        onFolderClicked: {
            ensureWallpaperDirProc.running = false
            ensureWallpaperDirProc.running = true
            openWallpaperDirProc.running = false
            openWallpaperDirProc.running = true
        }

        Item {
            width: parent.width
            height: 340

            GridView {
                anchors.fill: parent
                anchors.margins: 10
                cellWidth: 160; cellHeight: 110
                clip: true
                model: wallpaperModel

                delegate: Item {
                    id: wpTileRoot
                    width: 160; height: 110
                    readonly property bool selected: settingsWin.appliedWallpaper === model.filePath

                    Item {
                        id: wpTile
                        anchors.fill: parent
                        anchors.margins: 5

                        Canvas {
                            id: wpTileCanvas
                            anchors.fill: parent
                            property real hoverProgress: 0.0
                            property real activeProgress: wpTileRoot.selected ? 1.0 : 0.0
                            property real mx: 0.5
                            property real my: 0.5
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on activeProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            onHoverProgressChanged: requestPaint()
                            onActiveProgressChanged: requestPaint()
                            onMxChanged: requestPaint()
                            onMyChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: DivaPaint.paintFacetPill(wpTileCanvas, Math.max(hoverProgress, activeProgress), 8)
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true

                            Image {
                                anchors { fill: parent; bottomMargin: 18 }
                                source: "file://" + model.filePath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 18
                                color: "#99000000"

                                Text {
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 4; rightMargin: 4 }
                                    text: model.fileName
                                    color: wpTileRoot.selected ? "#8ff5f0" : "#cccccc"
                                    font.pixelSize: 9; font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            visible: wpTileRoot.selected
                            anchors { top: parent.top; right: parent.right; margins: 6 }
                            width: 16; height: 16
                            color: "#39c5bb"

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#0a1a1a"
                                font.pixelSize: 9; font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        id: wpTileArea
                        anchors.fill: wpTile
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: wpTileCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            wpTileCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            wpTileCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            settingsWin.appliedWallpaper = model.filePath
                            wallpaperProc.running = false
                            wallpaperProc.running = true
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
    }
}

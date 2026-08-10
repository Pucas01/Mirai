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
        status: settingsWin.wallpaperDir
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
    }
}

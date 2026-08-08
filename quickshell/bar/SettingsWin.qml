import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

Window {
    id: settingsWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-settings"
    color: "transparent"
    width: 720
    height: 500
    visible: false

    property string section: "wallpaper"
    property string wallpaperDir: "/home/pucas02/Pictures/Wallpapers"
    property string appliedWallpaper: ""

    onVisibleChanged: if (visible) { floatProc.running = false; floatProc.running = true }

    Process {
        id: floatProc
        command: ["hyprctl", "dispatch", "setfloating", "title:qs-settings"]
    }

    Process {
        id: wallpaperProc
        command: ["awww", "img", settingsWin.appliedWallpaper]
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#39c5bb"
        border.width: 1

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "settings"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "monospace"
            }

            Item {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 26; height: 26

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.containsMouse ? "#ffffff" : "#555555"
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: settingsWin.visible = false
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2a2a2a"
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) settingsWin.startSystemMove()
            }
        }

        Row {
            anchors { top: titleBar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }

            Rectangle {
                width: 150
                height: parent.height
                color: "#161616"

                Column {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }

                    component NavItem: Item {
                        property string label: ""
                        property string sym: ""
                        property string target: ""
                        width: parent.width
                        height: 38

                        Rectangle {
                            anchors.fill: parent
                            color: navArea.containsMouse || settingsWin.section === target ? "#242424" : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Rectangle {
                                width: 2; height: parent.height * 0.6
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                color: "#39c5bb"
                                opacity: settingsWin.section === target ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                        }

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: sym
                                color: settingsWin.section === target ? "#39c5bb" : "#555555"
                                font.pixelSize: 14
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: label
                                color: settingsWin.section === target ? "#ffffff" : "#666666"
                                font.pixelSize: 11; font.family: "monospace"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: settingsWin.section = target
                        }
                    }

                    NavItem { sym: "󰸉"; label: "wallpaper"; target: "wallpaper" }
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height

                Item {
                    anchors.fill: parent
                    visible: settingsWin.section === "wallpaper"

                    Item {
                        id: wpHeader
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: "wallpaper"
                            color: "#ffffff"
                            font.pixelSize: 13; font.family: "monospace"
                        }

                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            text: settingsWin.wallpaperDir
                            color: "#333333"
                            font.pixelSize: 9; font.family: "monospace"
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: "#2a2a2a"
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
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

Item {
    id: customizationSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: customizationSection.slideY }

    function refreshPfpModel() {
        pfpModel.folder = ""
        pfpModel.folder = Qt.binding(function() { return "file://" + settingsWin.pfpDir })
    }

    function refreshStartIconModel() {
        startIconModel.folder = ""
        startIconModel.folder = Qt.binding(function() { return "file://" + settingsWin.startIconDir })
    }

    property int cursorPreviewGen: 0
    function refreshCursorPreviews() {
        customizationSection.cursorPreviewGen++
    }

    readonly property string homeDir: Quickshell.env("HOME")
    property string logoDir: customizationSection.homeDir + "/Pictures/Mirai/Logos"
    property string logoStatePath: customizationSection.homeDir + "/.cache/qs-fastfetch-logo-path"
    property string logoPath: ""

    function setLogo(path) {
        customizationSection.logoPath = path
        saveLogoProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + customizationSection.logoStatePath + "\" <<'LOGO_EOF'\n" + path + "\nLOGO_EOF\n"]
        saveLogoProc.running = false
        saveLogoProc.running = true
    }

    function ensureDir() {
        ensureLogoDirProc.running = false
        ensureLogoDirProc.running = true
    }

    Component.onCompleted: loadLogoProc.running = true

    Process {
        id: loadLogoProc
        command: ["cat", customizationSection.logoStatePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { customizationSection.logoPath = text.trim() }
        }
    }

    Process {
        id: saveLogoProc
        command: ["true"]
        running: false
    }

    Process {
        id: ensureLogoDirProc
        command: ["mkdir", "-p", customizationSection.logoDir]
        running: false
        onExited: {
            logoModel.folder = ""
            logoModel.folder = Qt.binding(function() { return "file://" + customizationSection.logoDir })
        }
    }

    Process {
        id: openLogoDirProc
        command: ["nautilus", customizationSection.logoDir]
        running: false
    }

    Item {
        id: customizationHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
            label: "customization"
        }
    }

    Flickable {
        anchors { top: customizationHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: customContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: customContent
            width: parent.width
            spacing: 12
            topPadding: 4
            leftPadding: 16
            rightPadding: 16
            bottomPadding: 16

            FolderListModel {
                id: pfpModel
                folder: "file://" + settingsWin.pfpDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
                showDirs: false
            }

            SectionCard {
                title: "profile picture"
                path: settingsWin.pfpDir
                status: settingsWin.pfpDir
                onFolderClicked: {
                    settingsWin.ensurePfpDirProc.running = false
                    settingsWin.ensurePfpDirProc.running = true
                    settingsWin.openPfpDirProc.running = false
                    settingsWin.openPfpDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 208

                    GridView {
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 108; cellHeight: 108
                        clip: true
                        model: pfpModel

                        delegate: Item {
                            id: pfpTileRoot
                            width: 108; height: 108
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
                        anchors.centerIn: parent
                        visible: pfpModel.count === 0
                        text: "no images found\n" + settingsWin.pfpDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            FolderListModel {
                id: startIconModel
                folder: "file://" + settingsWin.startIconDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.svg", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.SVG"]
                showDirs: false
            }

            SectionCard {
                title: "start button icon"
                path: settingsWin.startIconDir
                status: settingsWin.startIconDir
                onFolderClicked: {
                    settingsWin.ensureStartIconDirProc.running = false
                    settingsWin.ensureStartIconDirProc.running = true
                    settingsWin.openStartIconDirProc.running = false
                    settingsWin.openStartIconDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 92

                    ListView {
                        id: startIconListView
                        anchors.fill: parent
                        anchors { leftMargin: 14; rightMargin: 14; topMargin: 4; bottomMargin: 10 }
                        orientation: ListView.Horizontal
                        spacing: 10
                        clip: true

                        model: startIconModel
                        delegate: Item {
                            id: startIconTile
                            width: 64; height: 64
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
                            width: 64; height: 64
                            readonly property bool selected: settingsWin.startIconPath === ""

                            Rectangle {
                                anchors.fill: parent
                                color: "#242424"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: settingsWin.defaultStartIcon
                                color: "#39c5bb"
                                font.pixelSize: 22
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
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 74 }
                            visible: startIconModel.count === 0
                            text: "no images found in " + settingsWin.startIconDir
                            color: "#444444"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }
                }
            }

            FolderListModel {
                id: logoModel
                folder: "file://" + customizationSection.logoDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.GIF"]
                showDirs: false
            }

            SectionCard {
                title: "fastfetch logo"
                path: customizationSection.logoDir
                status: customizationSection.logoDir
                onFolderClicked: {
                    customizationSection.ensureDir()
                    openLogoDirProc.running = false
                    openLogoDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 208

                    GridView {
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 108; cellHeight: 108
                        clip: true
                        model: logoModel

                        delegate: Item {
                            id: logoTileRoot
                            width: 108; height: 108
                            readonly property bool selected: customizationSection.logoPath === model.filePath

                            Item {
                                id: logoTile
                                anchors.fill: parent
                                anchors.margins: 8

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#242424"
                                }

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + model.filePath
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }

                            Rectangle {
                                z: 10
                                anchors.fill: logoTile
                                color: "transparent"
                                border.color: logoTileRoot.selected ? "#39c5bb" : "#2a2a2a"
                                border.width: logoTileRoot.selected ? 2 : 1
                            }

                            MouseArea {
                                anchors.fill: logoTile
                                cursorShape: Qt.PointingHandCursor
                                onClicked: customizationSection.setLogo(model.filePath)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: logoModel.count === 0
                        text: "no images found\n" + customizationSection.logoDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Process {
                id: listCursorThemesProc
                command: ["bash", "-c", "for base in /usr/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$base\" ] || continue; for d in \"$base\"/*/; do n=$(basename \"$d\"); [ -d \"${d}cursors\" ] && echo \"$n\"; done; done | sort -u"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        cursorThemeListModel.themes = text.trim().length > 0 ? text.trim().split("\n") : []
                    }
                }
            }

            QtObject {
                id: cursorThemeListModel
                property var themes: []
            }

            SectionCard {
                title: "cursor"
                path: settingsWin.cursorThemesDir
                status: settingsWin.cursorApplied ? "applied" : (settingsWin.cursorError.length > 0 ? settingsWin.cursorError : settingsWin.cursorTheme + " @ " + settingsWin.cursorSize + "px")
                statusColor: settingsWin.cursorApplied ? "#39c5bb" : (settingsWin.cursorError.length > 0 ? "#cc6666" : "#444444")
                onFolderClicked: {
                    openCursorThemesDirProc.running = false
                    openCursorThemesDirProc.running = true
                }

                Item {
                    width: parent.width
                    height: 116

                    GridView {
                        id: cursorThemeGrid
                        anchors.fill: parent
                        anchors.margins: 10
                        cellWidth: 100; cellHeight: 100
                        clip: true
                        model: cursorThemeListModel.themes

                        delegate: Item {
                            id: cursorThemeTile
                            width: 92; height: 92
                            readonly property bool selected: settingsWin.cursorTheme === modelData

                            Rectangle {
                                anchors.fill: parent
                                color: "#242424"
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    property int gen: customizationSection.cursorPreviewGen
                                    source: gen >= 0 ? "file://" + settingsWin.cursorPreviewsDir + "/" + modelData + ".png" : ""
                                    width: 28; height: 28
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: false
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 80
                                    text: modelData
                                    color: cursorThemeTile.selected ? "#39c5bb" : "#999999"
                                    font.pixelSize: 9; font.family: "monospace"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: cursorThemeTile.selected ? "#39c5bb" : "#2a2a2a"
                                border.width: cursorThemeTile.selected ? 2 : 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.applyCursor(modelData, settingsWin.cursorSize)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: cursorThemeListModel.themes.length === 0
                        text: "no cursor themes found\n" + settingsWin.cursorThemesDir
                        color: "#444444"
                        font.pixelSize: 11; font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    width: parent.width
                    height: 44

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                        text: "size"
                        color: "#666666"
                        font.pixelSize: 10; font.family: "monospace"
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                        spacing: 10

                        Repeater {
                            model: [16, 24, 32, 48, 64]

                            Item {
                                width: 34; height: 34
                                readonly property bool selected: settingsWin.cursorSize === modelData

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#242424"
                                    border.color: parent.selected ? "#39c5bb" : "#2a2a2a"
                                    border.width: parent.selected ? 2 : 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.selected ? "#39c5bb" : "#999999"
                                    font.pixelSize: 10; font.family: "monospace"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWin.applyCursor(settingsWin.cursorTheme, modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

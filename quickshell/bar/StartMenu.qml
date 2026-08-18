import QtQuick
import Quickshell
import Quickshell.Io
import "./SettingsWin"
import "./DivaPaint.js" as DivaPaint

Window {
    id: startMenuWin
    property bool isOpen: false
    property string username: ""
    property string searchText: ""
    property alias startIconPath: settingsWin.startIconPath
    readonly property string defaultStartIcon: settingsWin.defaultStartIcon
    property alias audioSliderActive: settingsWin.audioSliderActive

    function openSettings(section) {
        if (section) settingsWin.section = section
        settingsWin.visible = true
    }
    readonly property var kanadeEntry: ({
        id: "kanade",
        name: "Kanade",
        genericName: "music library & DAP sync",
        icon: "multimedia-player",
        execute: function() { kanadeToggleProc.running = false; kanadeToggleProc.running = true }
    })

    property var allApps: {
        try {
            return DesktopEntries.applications.values
                .filter(e => e && !e.noDisplay && e.name !== "")
                .concat([startMenuWin.kanadeEntry])
                .sort((a, b) => a.name.localeCompare(b.name))
        } catch(_) { return [] }
    }
    property var filteredApps: searchText === ""
        ? allApps
        : allApps.filter(e =>
            e.name.toLowerCase().includes(searchText.toLowerCase()) ||
            (e.genericName && e.genericName.toLowerCase().includes(searchText.toLowerCase()))
          )

    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 360
    height: 560
    visible: false

    function open(x, y) {
        startMenuWin.x = x
        startMenuWin.y = y
        isOpen = false
        visible = true
        smOpenTimer.start()
    }

    function closeMenu() {
        isOpen = false
        smSearch.text = ""
        smCloseTimer.start()
    }
    function launchApp(app) {
        app.execute()
        closeMenu()
    }
    onClosing: close => { if (isOpen) { close.accepted = false; closeMenu() } }

    Timer { id: smOpenTimer; interval: 10; onTriggered: { startMenuWin.isOpen = true; smSearch.forceActiveFocus() } }
    Timer { id: smCloseTimer; interval: 220; onTriggered: startMenuWin.visible = false }

    SettingsWin { id: settingsWin }

    Process { id: lockProc; command: ["quickshell", "ipc", "call", "lock", "lock"] }
    Process { id: kanadeToggleProc; command: ["quickshell", "ipc", "call", "kanade", "toggle"] }
    Process { id: logoutProc; command: ["bash", "-c", "hyprctl dispatch exit"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process {
        id: userProc
        command: ["id", "-un"]
        running: true
        stdout: SplitParser { onRead: data => startMenuWin.username = data.trim() }
    }

    PanelBackground {
        id: smRect
        anchors.fill: parent

        opacity: startMenuWin.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: startMenuWin.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: startMenuWin.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: 0; origin.y: 0; xScale: smRect.scaleVal; yScale: smRect.scaleVal },
            Translate { y: smRect.slideY }
        ]

        Column {
            anchors.fill: parent

            Item {
                width: parent.width
                height: 64

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    width: 38; height: 38; radius: 19
                    color: "#39c5bb"

                    Image {
                        id: avatarImage
                        visible: false
                        source: settingsWin.pfpPath !== "" ? "file://" + settingsWin.pfpPath : ""
                        asynchronous: true
                        onStatusChanged: if (status === Image.Ready) avatarCanvas.requestPaint()
                    }

                    Canvas {
                        id: avatarCanvas
                        anchors.fill: parent
                        visible: settingsWin.pfpPath !== ""
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (avatarImage.status !== Image.Ready) return
                            var iw = avatarImage.sourceSize.width, ih = avatarImage.sourceSize.height
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
                            ctx.drawImage(avatarImage, sx, sy, sw, sh, 0, 0, width, height)
                            ctx.restore()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: settingsWin.pfpPath === ""
                        text: startMenuWin.username.length > 0 ? startMenuWin.username[0].toUpperCase() : "?"
                        color: "#1a1a1a"
                        font.pixelSize: 18; font.bold: true; font.family: "monospace"
                    }
                }

                Column {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 66 }
                    spacing: 2
                    Text {
                        text: startMenuWin.username || "user"
                        color: "#ffffff"
                        font.pixelSize: 13; font.family: "monospace"
                    }
                    Text {
                        text: "Arch Linux"
                        color: "#39c5bb"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }

                Item {
                    id: settingsBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                    width: 30; height: 26

                    Canvas {
                        id: settingsBtnCanvas
                        anchors.fill: parent
                        property real hp: 0.0
                        property real mx: 0.5
                        property real my: 0.5
                        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        onHpChanged: requestPaint()
                        onMxChanged: requestPaint()
                        onMyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: DivaPaint.paintFacetPill(settingsBtnCanvas, settingsBtnCanvas.hp, 4)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        color: settingsBtnArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: settingsBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: settingsBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            settingsBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            settingsBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            startMenuWin.closeMenu()
                            settingsWin.visible = true
                        }
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                    height: 1; color: "#2a2a2a"
                }
            }

            Item {
                width: parent.width
                height: 48

                Item {
                    id: smSearchBox
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 6; bottomMargin: 6 }

                    Canvas {
                        id: smSearchBoxCanvas
                        anchors.fill: parent
                        property real focusProgress: smSearch.activeFocus ? 1.0 : 0.0
                        Behavior on focusProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onFocusProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 7, w = width, h = height, fp = focusProgress
                            function drawShape() {
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                            }
                            drawShape()
                            ctx.fillStyle = "#242424"; ctx.fill()
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                            ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.05 + fp * 0.04) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = fp > 0.5 ? "#c0f4f4" : "#3a3a3a"; ctx.lineWidth = 1; ctx.stroke()
                            drawShape()
                            ctx.strokeStyle = fp > 0 ? Qt.rgba(0.224, 0.773, 0.733, fp) : "#2e2e2e"
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                        text: "󰍉"
                        color: smSearch.activeFocus ? "#39c5bb" : "#444444"
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    TextInput {
                        id: smSearch
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 30; rightMargin: 8 }
                        color: "#dddddd"
                        font.pixelSize: 12; font.family: "monospace"
                        selectByMouse: true
                        onTextChanged: startMenuWin.searchText = text
                        Keys.onEscapePressed: startMenuWin.closeMenu()
                        Keys.onReturnPressed: {
                            var idx = appList.currentIndex >= 0 ? appList.currentIndex : 0
                            if (startMenuWin.filteredApps.length > 0)
                                startMenuWin.launchApp(startMenuWin.filteredApps[idx])
                        }
                        Keys.onUpPressed: appList.decrementCurrentIndex()
                        Keys.onDownPressed: appList.incrementCurrentIndex()
                    }
                }
            }

            Item {
                width: parent.width
                height: 24
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: startMenuWin.searchText === "" ? "all apps" : ("results (" + startMenuWin.filteredApps.length + ")")
                    color: "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            ListView {
                id: appList
                width: parent.width
                height: 356
                clip: true
                model: startMenuWin.filteredApps
                currentIndex: -1

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40

                    Rectangle {
                        anchors { fill: parent; leftMargin: 4; rightMargin: 8 }
                        color: appRowArea.containsMouse || appList.currentIndex === index ? "#242424" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Rectangle {
                            width: 2; height: parent.height * 0.6
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            color: "#39c5bb"
                            opacity: appRowArea.containsMouse || appList.currentIndex === index ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 80 } }
                        }

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                            spacing: 10

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: modelData.name
                                    color: appRowArea.containsMouse || appList.currentIndex === index ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 12; font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                Text {
                                    text: modelData.genericName ?? ""
                                    color: "#555555"
                                    font.pixelSize: 9; font.family: "monospace"
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            id: appRowArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) appList.currentIndex = index
                            onClicked: startMenuWin.launchApp(modelData)
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: "#2a2a2a"
            }

            Item {
                width: parent.width
                height: 67

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    component SysBtn: Item {
                        property string sym: ""
                        property string label: ""
                        signal activated()
                        width: 74; height: 50

                        Canvas {
                            id: sysBtnCanvas
                            anchors.fill: parent
                            property real hp: 0.0
                            property real mx: 0.5
                            property real my: 0.5
                            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            onHpChanged: requestPaint()
                            onMxChanged: requestPaint()
                            onMyChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: DivaPaint.paintFacetPill(sysBtnCanvas, sysBtnCanvas.hp, 5)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sym
                                color: sysBtnArea.containsMouse ? "#ffffff" : "#888888"
                                font.pixelSize: 16
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: label
                                color: sysBtnArea.containsMouse ? "#dddddd" : "#555555"
                                font.pixelSize: 9; font.family: "monospace"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                        }

                        MouseArea {
                            id: sysBtnArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: sysBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                            onPositionChanged: mouse => {
                                sysBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                sysBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                            }
                            onClicked: activated()
                        }
                    }

                    SysBtn { sym: "󰌾"; label: "lock";     onActivated: { lockProc.running = false; lockProc.running = true; startMenuWin.closeMenu() } }
                    SysBtn { sym: "󰍃"; label: "logout";   onActivated: { logoutProc.running = false; logoutProc.running = true } }
                    SysBtn { sym: "󰜉"; label: "reboot";   onActivated: { rebootProc.running = false; rebootProc.running = true } }
                    SysBtn { sym: "󰐥"; label: "shutdown"; onActivated: { shutdownProc.running = false; shutdownProc.running = true } }
                }
            }
        }
    }
}

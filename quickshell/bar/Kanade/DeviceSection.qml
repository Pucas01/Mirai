import QtQuick

Item {
    id: deviceSection
    property var kanadeWin: null
    property bool sectionActive: false
    visible: sectionActive
    anchors.fill: parent

    function formatBytes(n) {
        if (n <= 0) return "0 GB"
        var gb = n / (1024 * 1024 * 1024)
        return gb.toFixed(1) + " GB"
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 24

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "mounted devices"
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }

        Item {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 70; height: 22

            Canvas {
                id: refreshCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 4, w = width, h = height, hp = refreshCanvas.hp
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
                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                }
            }
            Text {
                anchors.centerIn: parent
                text: kanadeWin && kanadeWin.devicesRefreshing ? "..." : "refresh"
                color: refreshArea.containsMouse ? "#ffffff" : "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: refreshCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: if (kanadeWin) kanadeWin.refreshDevices()
            }
        }
    }

    Column {
        id: deviceList
        anchors { top: header.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 6 }
        spacing: 6

        Repeater {
            model: kanadeWin ? kanadeWin.devices : []
            delegate: Rectangle {
                required property var modelData
                width: deviceList.width
                height: 52
                color: kanadeWin && kanadeWin.selectedDevicePath === modelData.path ? "#20302f" : "#1e1e1e"
                border.color: kanadeWin && kanadeWin.selectedDevicePath === modelData.path ? "#39c5bb" : "#2a2a2a"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰄝"
                        color: kanadeWin && kanadeWin.selectedDevicePath === modelData.path ? "#39c5bb" : "#888888"
                        font.pixelSize: 18
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: modelData.name; color: "#e0e0e0"; font.pixelSize: 12; font.family: "monospace" }
                        Text {
                            text: deviceSection.formatBytes(modelData.avail) + " free of " + deviceSection.formatBytes(modelData.size)
                            color: "#666666"; font.pixelSize: 9; font.family: "monospace"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kanadeWin.selectedDevicePath = modelData.path
                }
            }
        }

        Text {
            visible: kanadeWin && kanadeWin.devices.length === 0
            text: "no removable devices found — plug in your DAP and hit refresh"
            color: "#444444"
            font.pixelSize: 11; font.family: "monospace"
        }
    }

    Rectangle {
        anchors { top: deviceList.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 20 }
        height: 1; color: "#2a2a2a"
    }

    Column {
        anchors { top: deviceList.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 30 }
        spacing: 10

        Text {
            text: "sync will reorganize your library into Artist / Album / Track on the device under a Music/ folder"
            color: "#777777"
            font.pixelSize: 10; font.family: "monospace"
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Text {
            visible: kanadeWin && kanadeWin.syncError !== ""
            text: kanadeWin ? kanadeWin.syncError : ""
            color: "#ff6b6b"
            font.pixelSize: 10; font.family: "monospace"
        }

        Item {
            width: parent.width
            height: 34

            Item {
                id: syncBtn
                width: 140; height: 32
                enabled: kanadeWin && !kanadeWin.syncing && kanadeWin.selectedDevicePath !== "" && kanadeWin.tracks.length > 0
                opacity: enabled ? 1.0 : 0.4

                Canvas {
                    id: syncCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cut = 6, w = width, h = height, hp = syncCanvas.hp
                        function drawShape() {
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                            ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                            ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                        }
                        drawShape()
                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                        ctx.fillStyle = teal; ctx.fill()
                        ctx.beginPath()
                        ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                        ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                        var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                        gloss.addColorStop(0, "rgba(255,255,255," + (0.14 + hp * 0.1) + ")")
                        gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                        ctx.fillStyle = gloss; ctx.fill()
                        ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                        ctx.strokeStyle = "#c0f4f4"; ctx.lineWidth = 1; ctx.stroke()
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: kanadeWin && kanadeWin.syncing ? "syncing..." : "sync to device"
                    color: "#0a1a1a"
                    font.pixelSize: 11; font.family: "monospace"; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: syncBtn.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: syncCanvas.hp = containsMouse ? 1.0 : 0.0
                    onClicked: kanadeWin.syncToDevice()
                }
            }

            Column {
                anchors { left: syncBtn.right; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                spacing: 4
                visible: kanadeWin && (kanadeWin.syncing || kanadeWin.syncStatusText !== "")

                Text {
                    text: kanadeWin ? kanadeWin.syncStatusText : ""
                    color: "#999999"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Rectangle {
                    width: 220; height: 4
                    color: "#242424"
                    Rectangle {
                        height: parent.height
                        width: kanadeWin && kanadeWin.syncTotal > 0 ? parent.width * (kanadeWin.syncDone / kanadeWin.syncTotal) : 0
                        color: "#39c5bb"
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }
    }
}

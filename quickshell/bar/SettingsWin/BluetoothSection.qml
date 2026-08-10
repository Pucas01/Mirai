import QtQuick
import Quickshell.Bluetooth

Item {
    id: bluetoothSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: bluetoothSection.slideY }

    readonly property var adapter: Bluetooth.defaultAdapter
    property var devices: bluetoothSection.adapter ? bluetoothSection.adapter.devices.values : []

    component ToggleSwitch: Item {
        property bool checked: false
        signal toggled()
        width: 40; height: 22

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.checked ? "#39c5bb" : "#2a2a2a"
            border.color: parent.checked ? "#39c5bb" : "#3a3a3a"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: parent.checked ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    component ActBtn: Item {
        property string label: ""
        property bool active: false
        signal clicked()
        width: 68; height: 24

        Canvas {
            id: actCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cut = 5, w = width, h = height, ta = parent.active ? 1.0 : Math.max(hp, 0)
                function drawShape() {
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - cut)
                    ctx.lineTo(w - cut, h); ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                }
                drawShape()
                var base = ctx.createLinearGradient(0, 0, 0, h)
                base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
                base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
                ctx.fillStyle = base; ctx.fill()
                if (ta > 0) {
                    drawShape()
                    var teal = ctx.createLinearGradient(0, 0, 0, h)
                    teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                    teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                    ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                }
                ctx.beginPath()
                ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + ta * 0.2) + ")")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss; ctx.fill()
                ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
            }
        }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: actBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
            font.pixelSize: 9; font.family: "monospace"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: actBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: actCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: parent.clicked()
        }
    }

    Item {
        id: btHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: btStatusText.left; rightMargin: 10 }
            label: "bluetooth"
        }

        Text {
            id: btStatusText
            anchors { right: btPowerSwitch.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            text: bluetoothSection.adapter ? (bluetoothSection.adapter.enabled ? "on" : "off") : "no adapter"
            color: "#666666"
            font.pixelSize: 10; font.family: "monospace"
        }

        ToggleSwitch {
            id: btPowerSwitch
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            checked: bluetoothSection.adapter ? bluetoothSection.adapter.enabled : false
            onToggled: if (bluetoothSection.adapter) bluetoothSection.adapter.enabled = !bluetoothSection.adapter.enabled
        }

    }

    Flickable {
        anchors { top: btHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: btContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: bluetoothSection.adapter !== null && bluetoothSection.adapter.enabled

        Column {
            id: btContent
            width: parent.width
            spacing: 0

            Item {
                width: parent.width
                height: 34

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: "devices"
                    color: "#666666"
                    font.pixelSize: 10; font.family: "monospace"
                }

                ActBtn {
                    anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 8 }
                    label: bluetoothSection.adapter && bluetoothSection.adapter.discovering ? "scanning..." : "scan"
                    active: bluetoothSection.adapter && bluetoothSection.adapter.discovering
                    onClicked: if (bluetoothSection.adapter) bluetoothSection.adapter.discovering = !bluetoothSection.adapter.discovering
                }
            }

            Repeater {
                model: bluetoothSection.devices
                delegate: Item {
                    id: btRow
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: 54

                    Rectangle {
                        anchors.fill: parent
                        color: btRowArea.containsMouse ? "#242424" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    MouseArea {
                        id: btRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Connections {
                        target: btRow.modelData
                        function onPairedChanged() {
                            if (btRow.modelData.paired) {
                                btRow.modelData.trusted = true
                                if (!btRow.modelData.connected) btRow.modelData.connect()
                            }
                        }
                    }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                        text: btRow.modelData.connected ? "󰂱" : "󰂯"
                        color: btRow.modelData.connected ? "#39c5bb" : "#666666"
                        font.pixelSize: 16
                    }

                    Column {
                        anchors { left: parent.left; right: btActions.left; verticalCenter: parent.verticalCenter; leftMargin: 42; rightMargin: 10 }
                        spacing: 2

                        Text {
                            width: parent.width
                            text: btRow.modelData.name || btRow.modelData.deviceName
                            color: "#cccccc"
                            font.pixelSize: 11; font.family: "monospace"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: {
                                if (btRow.modelData.pairing) return "pairing..."
                                if (btRow.modelData.connected) return btRow.modelData.batteryAvailable ? "connected · " + Math.round(btRow.modelData.battery * 100) + "%" : "connected"
                                if (btRow.modelData.paired) return "paired"
                                return "available"
                            }
                            color: "#666666"
                            font.pixelSize: 9; font.family: "monospace"
                        }
                    }

                    Row {
                        id: btActions
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                        spacing: 6

                        ActBtn {
                            label: btRow.modelData.pairing ? "..." : (btRow.modelData.connected ? "disconnect" : (btRow.modelData.paired ? "connect" : "pair"))
                            width: 76
                            onClicked: {
                                if (btRow.modelData.connected) btRow.modelData.disconnect()
                                else if (btRow.modelData.paired) btRow.modelData.connect()
                                else btRow.modelData.pair()
                            }
                        }

                        ActBtn {
                            visible: btRow.modelData.paired
                            label: "forget"
                            width: 56
                            onClicked: btRow.modelData.forget()
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: bluetoothSection.devices.length === 0
                text: "no devices found"
                color: "#444444"
                font.pixelSize: 11; font.family: "monospace"
                topPadding: 20
            }

            Item { width: parent.width; height: 16 }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !bluetoothSection.adapter
        text: "no bluetooth adapter found"
        color: "#444444"
        font.pixelSize: 12; font.family: "monospace"
    }

    Text {
        anchors.centerIn: parent
        visible: bluetoothSection.adapter !== null && !bluetoothSection.adapter.enabled
        text: "bluetooth is off"
        color: "#444444"
        font.pixelSize: 12; font.family: "monospace"
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

Window {
    id: ethWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "qs-ethernet"
    color: "transparent"
    width: 360
    height: 300
    visible: false

    property string connectionName: ""
    property bool connected: false
    property bool isAuto: true
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property string errorText: ""
    property bool loaded: false

    function open() {
        ethWin.visible = true
        ethWin.errorText = ""
        if (!ethWin.loaded) refresh()
    }

    function refresh() {
        if (!ethWin.connectionName) return
        configProc.command = ["nmcli", "-t", "-f", "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns", "connection", "show", ethWin.connectionName]
        configProc.running = false
        configProc.running = true
    }

    function splitTerse(line) {
        const parts = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length && line[i + 1] === ":") {
                cur += ":"
                i++
            } else if (ch === ":") {
                parts.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        parts.push(cur)
        return parts
    }

    Process {
        id: configProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                ethWin.loaded = true
                let method = "auto"
                let addr = ""
                let gw = ""
                let dns = ""
                const lines = text.split("\n")
                for (const line of lines) {
                    if (!line.trim()) continue
                    const parts = ethWin.splitTerse(line)
                    if (parts.length < 2) continue
                    const key = parts[0]
                    const val = parts.slice(1).join(":")
                    if (key === "ipv4.method") method = val
                    else if (key === "ipv4.addresses") addr = val
                    else if (key === "ipv4.gateway") gw = val
                    else if (key === "ipv4.dns") dns = val
                }
                ethWin.isAuto = method !== "manual"
                ethWin.address = addr
                ethWin.gateway = gw
                ethWin.dns = dns
            }
        }
    }

    signal toggleFinished()

    Process {
        id: toggleProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: ethWin.toggleFinished()
        }
    }

    Process {
        id: applyProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.toLowerCase().indexOf("error") !== -1) {
                    ethWin.errorText = text.trim()
                } else {
                    ethWin.errorText = ""
                    ethWin.loaded = false
                    ethWin.refresh()
                }
            }
        }
    }

    component NetToggle: Item {
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

    component NetActBtn: Item {
        property string label: ""
        property bool active: false
        signal clicked()
        width: 68; height: 24

        Canvas {
            id: netActCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, parent.active ? 1.0 : Math.max(hp, 0), 5)
        }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: netActBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
            font.pixelSize: 9; font.family: "monospace"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: netActBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: netActCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: parent.clicked()
        }
    }

    component EthField: Item {
        id: ethField
        property string label: ""
        property alias text: fieldInput.text
        property string placeholder: ""
        width: parent ? parent.width : 0
        height: 26

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 60
            text: ethField.label
            color: "#666666"
            font.pixelSize: 9; font.family: "monospace"
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 64 }
            height: 24
            color: "#242424"
            border.color: fieldInput.activeFocus ? "#39c5bb" : "#2e2e2e"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 130 } }

            TextInput {
                id: fieldInput
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                color: "#e0e0e0"
                font.pixelSize: 10; font.family: "monospace"
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    text: ethField.placeholder
                    color: "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                    verticalAlignment: Text.AlignVCenter
                    visible: fieldInput.text === "" && !fieldInput.activeFocus
                }
            }
        }
    }

    PanelBackground {
        anchors.fill: parent

        Item {
            id: ethTitleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "ethernet"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Item {
                id: ethCloseBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 28; height: 22

                Canvas {
                    id: ethCloseBtnCanvas
                    anchors.fill: parent
                    property real hp: 0.0
                    Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    onHpChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, ethCloseBtnCanvas.hp, 4, DivaPaint.ACCENT_RED)
                }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: ethCloseArea.containsMouse ? "#ffffff" : "#999999"
                    font.pixelSize: 11
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    id: ethCloseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: ethCloseBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                    onClicked: ethWin.visible = false
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2a2a2a"
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) ethWin.startSystemMove()
            }
        }

        Item {
            anchors { top: ethTitleBar.bottom; left: parent.left; right: parent.right; margins: 16 }
            height: 40

            Column {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 2

                Text {
                    text: ethWin.connectionName || "no connection"
                    color: "#cccccc"
                    font.pixelSize: 12; font.family: "monospace"
                }

                Text {
                    text: ethWin.connected ? "connected" : "disconnected"
                    color: ethWin.connected ? "#39c5bb" : "#666666"
                    font.pixelSize: 9; font.family: "monospace"
                }
            }

            NetToggle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                checked: ethWin.connected
                onToggled: {
                    toggleProc.command = ethWin.connected
                        ? ["nmcli", "connection", "down", ethWin.connectionName]
                        : ["nmcli", "connection", "up", ethWin.connectionName]
                    toggleProc.running = false
                    toggleProc.running = true
                }
            }
        }

        Rectangle {
            anchors { top: ethTitleBar.bottom; left: parent.left; right: parent.right; topMargin: 56 }
            height: 1; color: "#242424"
        }

        Row {
            anchors { top: ethTitleBar.bottom; left: parent.left; leftMargin: 16; topMargin: 68 }
            spacing: 6

            NetActBtn {
                label: "dhcp"
                width: 64
                active: ethWin.isAuto
                onClicked: ethWin.isAuto = true
            }
            NetActBtn {
                label: "manual"
                width: 64
                active: !ethWin.isAuto
                onClicked: ethWin.isAuto = false
            }
        }

        Column {
            anchors { top: ethTitleBar.bottom; left: parent.left; right: parent.right; topMargin: 106; leftMargin: 16; rightMargin: 16 }
            spacing: 8
            visible: !ethWin.isAuto

            EthField {
                id: addrField
                label: "address"
                placeholder: "192.168.1.50/24"
                text: ethWin.address
            }
            EthField {
                id: gwField
                label: "gateway"
                placeholder: "192.168.1.1"
                text: ethWin.gateway
            }
            EthField {
                id: dnsField
                label: "dns"
                placeholder: "1.1.1.1"
                text: ethWin.dns
            }
        }

        NetActBtn {
            anchors { left: parent.left; leftMargin: 16; top: ethTitleBar.bottom; topMargin: ethWin.isAuto ? 106 : 202 }
            label: "apply"
            width: 64
            onClicked: {
                if (!ethWin.connectionName) return
                let cmd
                if (ethWin.isAuto) {
                    cmd = ["nmcli", "connection", "modify", ethWin.connectionName, "ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""]
                } else {
                    cmd = ["nmcli", "connection", "modify", ethWin.connectionName, "ipv4.method", "manual", "ipv4.addresses", addrField.text, "ipv4.gateway", gwField.text, "ipv4.dns", dnsField.text]
                }
                applyProc.command = cmd
                applyProc.running = false
                applyProc.running = true
            }
        }

        Text {
            anchors { left: parent.left; leftMargin: 90; top: ethTitleBar.bottom; topMargin: ethWin.isAuto ? 110 : 206; right: parent.right; rightMargin: 16 }
            visible: ethWin.errorText !== ""
            text: ethWin.errorText
            color: "#ff6b6b"
            font.pixelSize: 9; font.family: "monospace"
            wrapMode: Text.WordWrap
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

Window {
    id: networkPopup
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 300
    height: 380
    visible: false

    function open(x, y) {
        networkPopup.x = x
        networkPopup.y = y
        isOpen = false
        visible = true
        netOpenTimer.start()
        refreshAll()
    }

    function closePopup() {
        isOpen = false
        netCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: netOpenTimer; interval: 10; onTriggered: networkPopup.isOpen = true }
    Timer { id: netCloseTimer; interval: 220; onTriggered: networkPopup.visible = false }

    property bool wifiPresent: false
    property bool wifiEnabled: false
    property bool scanning: false
    property var wifiAps: []
    property string ethernetName: ""
    property bool ethernetConnected: false
    property string connectTarget: ""
    property string connectError: ""

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

    function refreshRadio() { radioProc.running = false; radioProc.running = true }
    function refreshAps() { apListProc.running = false; apListProc.running = true }
    function refreshActive() { activeProc.running = false; activeProc.running = true }
    function refreshAll() { refreshRadio(); refreshAps(); refreshActive() }

    Timer {
        interval: 6000
        running: networkPopup.isOpen
        repeat: true
        onTriggered: networkPopup.refreshAll()
    }

    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim()
                networkPopup.wifiPresent = v === "enabled" || v === "disabled"
                networkPopup.wifiEnabled = v === "enabled"
            }
        }
    }

    Process { id: radioToggleProc; command: [] }

    Process {
        id: apListProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                networkPopup.scanning = false
                const seen = {}
                const list = []
                const lines = text.split("\n")
                for (const line of lines) {
                    if (!line.trim()) continue
                    const parts = networkPopup.splitTerse(line)
                    if (parts.length < 4) continue
                    const active = parts[0] === "yes"
                    const ssid = parts[1]
                    const signal = parseInt(parts[2]) || 0
                    const security = parts.slice(3).join(":")
                    if (!ssid) continue
                    if (seen[ssid] !== undefined) {
                        if (active) seen[ssid].active = true
                        continue
                    }
                    const entry = { ssid: ssid, signal: signal, secured: security !== "" && security !== "--", active: active }
                    seen[ssid] = entry
                    list.push(entry)
                }
                list.sort((a, b) => b.signal - a.signal)
                networkPopup.wifiAps = list
            }
        }
    }

    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ethName = ""
                let ethUp = false
                const lines = text.split("\n")
                for (const line of lines) {
                    if (!line.trim()) continue
                    const parts = networkPopup.splitTerse(line)
                    if (parts.length < 4) continue
                    if (parts[1] === "802-3-ethernet") {
                        ethName = parts[0]
                        ethUp = parts[3] === "yes"
                    }
                }
                networkPopup.ethernetName = ethName
                networkPopup.ethernetConnected = ethUp
            }
        }
    }

    Process {
        id: ethToggleProc
        command: []
        stdout: StdioCollector { onStreamFinished: networkPopup.refreshActive() }
    }

    Process {
        id: connectProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.toLowerCase().indexOf("error") !== -1) {
                    networkPopup.connectError = text.trim()
                } else {
                    networkPopup.connectTarget = ""
                    networkPopup.connectError = ""
                }
                networkPopup.refreshAll()
            }
        }
    }

    component NetToggle: Item {
        property bool checked: false
        signal toggled()
        width: 36; height: 20

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.checked ? "#39c5bb" : "#2a2a2a"
            border.color: parent.checked ? "#39c5bb" : "#3a3a3a"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Rectangle {
            width: 14; height: 14; radius: 7
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
        width: 64; height: 22

        Canvas {
            id: netActCanvas
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
            onPaint: DivaPaint.paintFacetPill(netActCanvas, parent.active ? 1.0 : Math.max(hp, 0), 5)
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
            onPositionChanged: mouse => {
                netActCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                netActCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
            }
            onClicked: parent.clicked()
        }
    }

    PanelBackground {
        id: netRect
        anchors.fill: parent

        opacity: networkPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: networkPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: networkPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: netRect.width / 2; origin.y: 0; xScale: netRect.scaleVal; yScale: netRect.scaleVal },
            Translate { y: netRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 54

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: networkPopup.ethernetConnected ? "󰈀" : "󰈂"
                    color: networkPopup.ethernetConnected ? "#39c5bb" : "#666666"
                    font.pixelSize: 16
                }

                Column {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 40 }
                    spacing: 2

                    Text {
                        text: "ethernet"
                        color: "#cccccc"
                        font.pixelSize: 11; font.family: "monospace"
                    }

                    Text {
                        text: networkPopup.ethernetConnected ? networkPopup.ethernetName : "not connected"
                        color: "#666666"
                        font.pixelSize: 9; font.family: "monospace"
                        elide: Text.ElideRight
                        width: 140
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    spacing: 8

                    NetActBtn {
                        label: "edit"
                        width: 46
                        visible: networkPopup.ethernetName !== ""
                        onClicked: {
                            ethernetPopupWin.connectionName = networkPopup.ethernetName
                            ethernetPopupWin.connected = networkPopup.ethernetConnected
                            ethernetPopupWin.open()
                        }
                    }

                    NetToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: networkPopup.ethernetName !== ""
                        checked: networkPopup.ethernetConnected
                        onToggled: {
                            ethToggleProc.command = networkPopup.ethernetConnected
                                ? ["nmcli", "connection", "down", networkPopup.ethernetName]
                                : ["nmcli", "connection", "up", networkPopup.ethernetName]
                            ethToggleProc.running = false
                            ethToggleProc.running = true
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            Item {
                width: parent.width
                height: 30
                visible: networkPopup.wifiPresent

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: "wifi"
                    color: "#666666"
                    font.pixelSize: 10; font.family: "monospace"
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    spacing: 8

                    NetActBtn {
                        label: networkPopup.scanning ? "..." : "scan"
                        width: 44
                        active: networkPopup.scanning
                        visible: networkPopup.wifiEnabled
                        onClicked: {
                            networkPopup.scanning = true
                            apListProc.command = ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
                            networkPopup.refreshAps()
                        }
                    }

                    NetToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: networkPopup.wifiEnabled
                        onToggled: {
                            radioToggleProc.command = ["nmcli", "radio", "wifi", networkPopup.wifiEnabled ? "off" : "on"]
                            radioToggleProc.running = false
                            radioToggleProc.running = true
                            networkPopup.wifiEnabled = !networkPopup.wifiEnabled
                        }
                    }
                }
            }

            ListView {
                width: parent.width
                height: parent.height - 54 - 1 - 30
                clip: true
                visible: networkPopup.wifiPresent && networkPopup.wifiEnabled
                model: networkPopup.wifiAps
                spacing: 0

                delegate: Item {
                    id: apRow
                    required property var modelData
                    width: ListView.view.width
                    height: networkPopup.connectTarget === modelData.ssid ? 100 : 44
                    clip: true
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Text {
                        anchors { left: parent.left; top: parent.top; topMargin: 12; leftMargin: 14 }
                        text: apRow.modelData.signal > 66 ? "󰤨" : (apRow.modelData.signal > 33 ? "󰤢" : "󰤟")
                        color: apRow.modelData.active ? "#39c5bb" : "#666666"
                        font.pixelSize: 14
                    }

                    Column {
                        anchors { left: parent.left; right: apActions.left; top: parent.top; topMargin: 8; leftMargin: 34; rightMargin: 6 }
                        spacing: 2

                        Text {
                            width: parent.width
                            text: apRow.modelData.ssid
                            color: "#cccccc"
                            font.pixelSize: 10; font.family: "monospace"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: (apRow.modelData.active ? "connected · " : "") + (apRow.modelData.secured ? "secured" : "open")
                            color: "#666666"
                            font.pixelSize: 8; font.family: "monospace"
                        }
                    }

                    Row {
                        id: apActions
                        anchors { right: parent.right; top: parent.top; topMargin: 11; rightMargin: 10 }
                        spacing: 4

                        NetActBtn {
                            visible: !apRow.modelData.active
                            label: networkPopup.connectTarget === apRow.modelData.ssid ? "x" : "connect"
                            width: networkPopup.connectTarget === apRow.modelData.ssid ? 22 : 56
                            onClicked: {
                                if (networkPopup.connectTarget === apRow.modelData.ssid) {
                                    networkPopup.connectTarget = ""
                                    return
                                }
                                networkPopup.connectError = ""
                                if (apRow.modelData.secured) {
                                    networkPopup.connectTarget = apRow.modelData.ssid
                                } else {
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid]
                                    connectProc.running = false
                                    connectProc.running = true
                                }
                            }
                        }

                        NetActBtn {
                            visible: apRow.modelData.active
                            label: "off"
                            width: 40
                            onClicked: {
                                connectProc.command = ["nmcli", "connection", "down", apRow.modelData.ssid]
                                connectProc.running = false
                                connectProc.running = true
                            }
                        }
                    }

                    Item {
                        anchors { top: parent.top; topMargin: 44; left: parent.left; right: parent.right }
                        height: 50
                        visible: networkPopup.connectTarget === apRow.modelData.ssid

                        Rectangle {
                            id: apPwBox
                            anchors { left: parent.left; leftMargin: 14; right: apConnectBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            height: 26
                            color: "#242424"
                            border.color: networkPopup.connectError !== "" ? "#ff6b6b" : (apPwInput.activeFocus ? "#39c5bb" : "#2e2e2e")
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            TextInput {
                                id: apPwInput
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#e0e0e0"
                                font.pixelSize: 10; font.family: "monospace"
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                selectByMouse: true
                                focus: networkPopup.connectTarget === apRow.modelData.ssid

                                Keys.onReturnPressed: {
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid, "password", text]
                                    connectProc.running = false
                                    connectProc.running = true
                                }
                            }
                        }

                        NetActBtn {
                            id: apConnectBtn
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: apPwBox.verticalCenter }
                            label: "go"
                            width: 34
                            onClicked: {
                                connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid, "password", apPwInput.text]
                                connectProc.running = false
                                connectProc.running = true
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: networkPopup.wifiAps.length === 0
                    text: "no networks found"
                    color: "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !networkPopup.wifiPresent
                text: "no wifi adapter"
                color: "#444444"
                font.pixelSize: 11; font.family: "monospace"
                topPadding: 30
            }
        }
    }

    EthernetWin {
        id: ethernetPopupWin
        onToggleFinished: networkPopup.refreshActive()
    }
}

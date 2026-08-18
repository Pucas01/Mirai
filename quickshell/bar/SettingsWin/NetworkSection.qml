import QtQuick
import Quickshell.Io
import "../DivaPaint.js" as DivaPaint

Item {
    id: networkSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: networkSection.slideY }

    property bool wifiPresent: false
    property bool wifiEnabled: false
    property bool scanning: false
    property var wifiAps: []
    property string ethernetName: ""
    property string ethernetDevice: ""
    property bool ethernetConnected: false
    property string connectTarget: ""
    property bool connectSecured: false
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

    function refreshRadio() {
        radioProc.running = false
        radioProc.running = true
    }

    function refreshAps() {
        apListProc.running = false
        apListProc.running = true
    }

    function refreshActive() {
        activeProc.running = false
        activeProc.running = true
    }

    function refreshAll() {
        refreshRadio()
        refreshAps()
        refreshActive()
    }

    Component.onCompleted: refreshAll()

    Timer {
        interval: 8000
        running: networkSection.sectionActive
        repeat: true
        onTriggered: networkSection.refreshAll()
    }

    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim()
                networkSection.wifiPresent = v === "enabled" || v === "disabled"
                networkSection.wifiEnabled = v === "enabled"
            }
        }
    }

    Process {
        id: radioToggleProc
        command: []
    }

    Process {
        id: apListProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                networkSection.scanning = false
                const seen = {}
                const list = []
                const lines = text.split("\n")
                for (const line of lines) {
                    if (!line.trim()) continue
                    const parts = networkSection.splitTerse(line)
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
                networkSection.wifiAps = list
            }
        }
    }

    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ethName = ""
                let ethDevice = ""
                let ethUp = false
                const lines = text.split("\n")
                for (const line of lines) {
                    if (!line.trim()) continue
                    const parts = networkSection.splitTerse(line)
                    if (parts.length < 4) continue
                    const type = parts[1]
                    if (type === "802-3-ethernet") {
                        ethName = parts[0]
                        ethDevice = parts[2]
                        ethUp = parts[3] === "yes"
                    }
                }
                networkSection.ethernetName = ethName
                networkSection.ethernetDevice = ethDevice
                networkSection.ethernetConnected = ethUp
            }
        }
    }

    Process {
        id: ethToggleProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: networkSection.refreshActive()
        }
    }

    Process {
        id: connectProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.toLowerCase().indexOf("error") !== -1) {
                    networkSection.connectError = text.trim()
                } else {
                    networkSection.connectTarget = ""
                    networkSection.connectError = ""
                }
                networkSection.refreshAll()
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

    Item {
        id: netHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: netStatusText.left; rightMargin: 10 }
            label: "network"
        }

        Text {
            id: netStatusText
            anchors { right: wifiPowerSwitch.left; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            text: !networkSection.wifiPresent ? "no wifi adapter" : (networkSection.wifiEnabled ? "on" : "off")
            color: "#666666"
            font.pixelSize: 10; font.family: "monospace"
        }

        NetToggle {
            id: wifiPowerSwitch
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            visible: networkSection.wifiPresent
            checked: networkSection.wifiEnabled
            onToggled: {
                radioToggleProc.command = ["nmcli", "radio", "wifi", networkSection.wifiEnabled ? "off" : "on"]
                radioToggleProc.running = false
                radioToggleProc.running = true
                networkSection.wifiEnabled = !networkSection.wifiEnabled
            }
        }
    }

    Flickable {
        anchors { top: netHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: netContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: netContent
            width: parent.width
            spacing: 12
            topPadding: 4
            leftPadding: 16
            rightPadding: 16
            bottomPadding: 16

            SectionCard {
                title: "ethernet"

                Item {
                    id: ethRow
                    width: parent.width
                    height: 54

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                        text: networkSection.ethernetConnected ? "󰈀" : "󰈂"
                        color: networkSection.ethernetConnected ? "#39c5bb" : "#666666"
                        font.pixelSize: 16
                    }

                    Column {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 42 }
                        spacing: 2

                        Text {
                            text: networkSection.ethernetName !== "" ? networkSection.ethernetName : "not detected"
                            color: "#cccccc"
                            font.pixelSize: 11; font.family: "monospace"
                        }

                        Text {
                            text: networkSection.ethernetConnected ? "connected" : "not connected"
                            color: "#666666"
                            font.pixelSize: 9; font.family: "monospace"
                        }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                        spacing: 8

                        NetActBtn {
                            label: "edit"
                            width: 52
                            visible: networkSection.ethernetName !== ""
                            onClicked: settingsWin.ethernetWin.open()
                        }

                        NetToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: networkSection.ethernetName !== ""
                            checked: networkSection.ethernetConnected
                            onToggled: {
                                ethToggleProc.command = networkSection.ethernetConnected
                                    ? ["nmcli", "connection", "down", networkSection.ethernetName]
                                    : ["nmcli", "connection", "up", networkSection.ethernetName]
                                ethToggleProc.running = false
                                ethToggleProc.running = true
                            }
                        }
                    }
                }
            }

            SectionCard {
                title: "networks"
                visible: networkSection.wifiPresent && networkSection.wifiEnabled

                headerAction: NetActBtn {
                    label: networkSection.scanning ? "scanning..." : "scan"
                    active: networkSection.scanning
                    onClicked: {
                        networkSection.scanning = true
                        apListProc.command = ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
                        networkSection.refreshAps()
                    }
                }

                Repeater {
                    model: networkSection.wifiPresent && networkSection.wifiEnabled ? networkSection.wifiAps : []
                    delegate: Item {
                        id: apRow
                    required property var modelData
                    width: parent ? parent.width : 0
                    height: networkSection.connectTarget === modelData.ssid ? 118 : 54

                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    clip: true

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 54
                        color: apRowArea.containsMouse ? "#242424" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    MouseArea {
                        id: apRowArea
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 54
                        hoverEnabled: true
                    }

                    Text {
                        anchors { left: parent.left; top: parent.top; topMargin: 16; leftMargin: 16 }
                        text: apRow.modelData.signal > 66 ? "󰤨" : (apRow.modelData.signal > 33 ? "󰤢" : "󰤟")
                        color: apRow.modelData.active ? "#39c5bb" : "#666666"
                        font.pixelSize: 16
                    }

                    Column {
                        anchors { left: parent.left; right: apActions.left; top: parent.top; topMargin: 12; leftMargin: 42; rightMargin: 10 }
                        spacing: 2

                        Text {
                            width: parent.width
                            text: apRow.modelData.ssid
                            color: "#cccccc"
                            font.pixelSize: 11; font.family: "monospace"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: (apRow.modelData.active ? "connected · " : "") + (apRow.modelData.secured ? "secured" : "open") + " · " + apRow.modelData.signal + "%"
                            color: "#666666"
                            font.pixelSize: 9; font.family: "monospace"
                        }
                    }

                    Row {
                        id: apActions
                        anchors { right: parent.right; top: parent.top; topMargin: 15; rightMargin: 12 }
                        spacing: 6

                        NetActBtn {
                            visible: !apRow.modelData.active
                            label: networkSection.connectTarget === apRow.modelData.ssid ? "cancel" : "connect"
                            width: 68
                            onClicked: {
                                if (networkSection.connectTarget === apRow.modelData.ssid) {
                                    networkSection.connectTarget = ""
                                    return
                                }
                                networkSection.connectError = ""
                                if (apRow.modelData.secured) {
                                    networkSection.connectTarget = apRow.modelData.ssid
                                    networkSection.connectSecured = true
                                } else {
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid]
                                    connectProc.running = false
                                    connectProc.running = true
                                }
                            }
                        }

                        NetActBtn {
                            visible: apRow.modelData.active
                            label: "disconnect"
                            width: 76
                            onClicked: {
                                connectProc.command = ["nmcli", "connection", "down", apRow.modelData.ssid]
                                connectProc.running = false
                                connectProc.running = true
                            }
                        }
                    }

                    Item {
                        anchors { top: parent.top; topMargin: 54; left: parent.left; right: parent.right }
                        height: 64
                        visible: networkSection.connectTarget === apRow.modelData.ssid

                        Item {
                            id: apPwBox
                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                            width: parent.width - 32 - 76
                            height: 32

                            property real focusProgress: apPwInput.activeFocus ? 1.0 : 0.0
                            Behavior on focusProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onFocusProgressChanged: apPwCanvas.requestPaint()

                            Canvas {
                                id: apPwCanvas
                                anchors.fill: parent
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: networkSection
                                    function onConnectErrorChanged() { apPwCanvas.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 6, w = width, h = height, fp = apPwBox.focusProgress
                                    var isErr = networkSection.connectError !== ""
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
                                    if (fp > 0 && !isErr) {
                                        drawShape()
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                                        ctx.globalAlpha = fp * 0.18; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.55)
                                    ctx.lineTo(0, h * 0.55); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                                    gloss.addColorStop(0, "rgba(255,255,255,0.12)")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = isErr ? "#ff6b6b" : (fp > 0.5 ? "#c0f4f4" : "#646464")
                                    ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            TextInput {
                                id: apPwInput
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#e0e0e0"
                                font.pixelSize: 12; font.family: "monospace"
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                selectByMouse: true
                                focus: networkSection.connectTarget === apRow.modelData.ssid

                                Keys.onReturnPressed: {
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid, "password", text]
                                    connectProc.running = false
                                    connectProc.running = true
                                }
                            }
                        }

                        NetActBtn {
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: apPwBox.verticalCenter }
                            label: "connect"
                            width: 68
                            onClicked: {
                                connectProc.command = ["nmcli", "device", "wifi", "connect", apRow.modelData.ssid, "password", apPwInput.text]
                                connectProc.running = false
                                connectProc.running = true
                            }
                        }
                    }
                }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: networkSection.wifiPresent && networkSection.wifiEnabled && networkSection.wifiAps.length === 0
                    text: "no networks found"
                    color: "#444444"
                    font.pixelSize: 11; font.family: "monospace"
                    topPadding: 20
                    bottomPadding: 12
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: networkSection.connectError !== ""
                    text: networkSection.connectError
                    color: "#ff6b6b"
                    font.pixelSize: 10; font.family: "monospace"
                    topPadding: 10
                    bottomPadding: 10
                }
            }
        }
    }
}

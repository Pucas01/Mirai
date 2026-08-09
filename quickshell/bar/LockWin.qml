import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

Item {
    id: lockRoot

    property string password: ""
    property string statusText: ""
    property bool isError: false
    property bool authenticating: false
    property string username: ""
    property var wallpapers: ({})
    property string fallbackWallpaper: ""
    property var activePlayer: {
        var players = Mpris.players.values
        return players.find(p => p.isPlaying) ?? (players.length > 0 ? players[0] : null)
    }

    Process {
        id: userProc
        command: ["id", "-un"]
        running: true
        stdout: SplitParser { onRead: data => lockRoot.username = data.trim() }
    }

    Process {
        id: wallpaperQuery
        command: ["awww", "query"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                let first = ""
                const lines = text.split("\n")
                for (const line of lines) {
                    const m = line.match(/^:\s*(\S+):.*currently displaying: image: (.+)$/)
                    if (m) {
                        map[m[1]] = m[2].trim()
                        if (!first) first = m[2].trim()
                    }
                }
                lockRoot.wallpapers = map
                lockRoot.fallbackWallpaper = first
            }
        }
    }

    Timer {
        id: clockTimer
        property var now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockTimer.now = new Date()
    }

    function engage() {
        if (sessionLock.locked) return
        password = ""
        statusText = ""
        isError = false
        authenticating = false
        wallpaperQuery.running = false
        wallpaperQuery.running = true
        sessionLock.locked = true
    }

    function submit() {
        if (lockRoot.authenticating || lockRoot.password.length === 0) return
        lockRoot.authenticating = true
        lockRoot.statusText = "checking..."
        lockRoot.isError = false
        pam.user = lockRoot.username
        const started = pam.start()
        if (!started) {
            lockRoot.authenticating = false
            lockRoot.statusText = "failed to start auth"
            lockRoot.isError = true
            lockRoot.password = ""
        } else {
            authTimeout.restart()
        }
    }

    Timer {
        id: authTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            if (!lockRoot.authenticating) return
            pam.active = false
            lockRoot.authenticating = false
            lockRoot.statusText = "timed out, try again"
            lockRoot.isError = true
            lockRoot.password = ""
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockRoot.engage() }
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(lockRoot.password)
        }

        onCompleted: result => {
            authTimeout.stop()
            lockRoot.authenticating = false
            if (result === PamResult.Success) {
                lockRoot.password = ""
                sessionLock.locked = false
            } else {
                lockRoot.statusText = "incorrect password"
                lockRoot.isError = true
                lockRoot.password = ""
            }
        }

        onError: error => {
            authTimeout.stop()
            lockRoot.authenticating = false
            lockRoot.statusText = "authentication error"
            lockRoot.isError = true
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface
                color: "#1a1a1a"

                readonly property string wallpaperSource: {
                    const name = lockSurface.screen ? lockSurface.screen.name : ""
                    return (name && lockRoot.wallpapers[name]) ? lockRoot.wallpapers[name] : lockRoot.fallbackWallpaper
                }

                Item {
                    id: fadeRoot
                    anchors.fill: parent

                    Image {
                        id: bgImage
                        anchors.fill: parent
                        source: lockSurface.wallpaperSource ? "file://" + lockSurface.wallpaperSource : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: bgImage
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        autoPaddingEnabled: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#66000000"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clockTimer.now, "hh:mm")
                            color: "#ffffff"
                            font.pixelSize: 64; font.family: "Orbitron"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clockTimer.now, "dddd, MMMM d")
                            color: "#39c5bb"
                            font.pixelSize: 16; font.family: "monospace"
                        }

                        Item { width: 1; height: 30 }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: lockRoot.username
                            color: "#999999"
                            font.pixelSize: 12; font.family: "monospace"
                        }

                        Item { width: 1; height: 4 }

                        Item {
                            id: pwBox
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 240; height: 40

                            property real focusProgress: pwInput.activeFocus ? 1.0 : 0.0
                            Behavior on focusProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onFocusProgressChanged: pwCanvas.requestPaint()

                            Canvas {
                                id: pwCanvas
                                anchors.fill: parent
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: lockRoot
                                    function onIsErrorChanged() { pwCanvas.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 8, w = width, h = height, fp = pwBox.focusProgress
                                    function drawShape() {
                                        ctx.beginPath()
                                        ctx.moveTo(cut, 0)
                                        ctx.lineTo(w,       0)
                                        ctx.lineTo(w,       h - cut)
                                        ctx.lineTo(w - cut, h)
                                        ctx.lineTo(0,       h)
                                        ctx.lineTo(0,       cut)
                                        ctx.closePath()
                                    }
                                    drawShape()
                                    var base = ctx.createLinearGradient(0, 0, 0, h)
                                    base.addColorStop(0,    "#3d3d3d")
                                    base.addColorStop(0.08, "#2a2a2a")
                                    base.addColorStop(0.5,  "#303030")
                                    base.addColorStop(1.0,  "#3a3a3a")
                                    ctx.fillStyle = base
                                    ctx.fill()
                                    if (fp > 0 && !lockRoot.isError) {
                                        drawShape()
                                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                                        teal.addColorStop(0,    "#80e0e0")
                                        teal.addColorStop(0.08, "#39c5bb")
                                        teal.addColorStop(0.5,  "#2a8a8a")
                                        teal.addColorStop(1.0,  "#3a6a6a")
                                        ctx.globalAlpha = fp * 0.18
                                        ctx.fillStyle = teal
                                        ctx.fill()
                                        ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0)
                                    ctx.lineTo(w,   0)
                                    ctx.lineTo(w,   h * 0.55)
                                    ctx.lineTo(0,   h * 0.55)
                                    ctx.lineTo(0,   cut)
                                    ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                                    gloss.addColorStop(0, "rgba(255,255,255,0.12)")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss
                                    ctx.fill()
                                    ctx.beginPath()
                                    ctx.moveTo(cut, 0.5)
                                    ctx.lineTo(w,   0.5)
                                    ctx.strokeStyle = lockRoot.isError ? "#ff6b6b" : (fp > 0.5 ? "#c0f4f4" : "#646464")
                                    ctx.lineWidth = 1
                                    ctx.stroke()
                                }
                            }

                            TextInput {
                                id: pwInput
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#e0e0e0"
                                font.pixelSize: 14; font.family: "monospace"
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                enabled: !lockRoot.authenticating
                                selectByMouse: true
                                focus: true

                                onTextChanged: lockRoot.password = text
                                Keys.onReturnPressed: lockRoot.submit()
                                Keys.onEscapePressed: {
                                    if (lockRoot.authenticating) {
                                        authTimeout.stop()
                                        pam.active = false
                                        lockRoot.authenticating = false
                                    }
                                    text = ""; lockRoot.password = ""; lockRoot.statusText = ""; lockRoot.isError = false
                                }

                                Connections {
                                    target: lockRoot
                                    function onPasswordChanged() { if (lockRoot.password === "") pwInput.text = "" }
                                }
                            }
                        }

                        Item { width: 1; height: 4 }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: lockRoot.statusText !== ""
                            text: lockRoot.statusText
                            color: lockRoot.isError ? "#ff6b6b" : "#666666"
                            font.pixelSize: 10; font.family: "monospace"
                        }

                        Item { width: 1; height: lockRoot.activePlayer ? 22 : 0 }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            visible: lockRoot.activePlayer !== null

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 220
                                text: lockRoot.activePlayer ? lockRoot.activePlayer.trackTitle : ""
                                color: "#d0d0d0"
                                font.pixelSize: 12; font.family: "monospace"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 220
                                text: lockRoot.activePlayer ? lockRoot.activePlayer.trackArtist : ""
                                color: "#666666"
                                font.pixelSize: 10; font.family: "monospace"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Item { width: 1; height: 2 }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 10

                                component LockMediaBtn: Item {
                                    width: 44
                                    height: 32
                                    property string sym: ""
                                    signal activated()

                                    Canvas {
                                        id: lmCanvas
                                        anchors.fill: parent
                                        property real hoverProgress: 0.0
                                        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                        onHoverProgressChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cut = 5, w = width, h = height, hp = hoverProgress
                                            function drawShape() {
                                                ctx.beginPath()
                                                ctx.moveTo(cut, 0)
                                                ctx.lineTo(w,       0)
                                                ctx.lineTo(w,       h - cut)
                                                ctx.lineTo(w - cut, h)
                                                ctx.lineTo(0,       h)
                                                ctx.lineTo(0,       cut)
                                                ctx.closePath()
                                            }
                                            drawShape()
                                            var base = ctx.createLinearGradient(0, 0, 0, h)
                                            base.addColorStop(0,    "#3d3d3d")
                                            base.addColorStop(0.08, "#2a2a2a")
                                            base.addColorStop(0.5,  "#303030")
                                            base.addColorStop(1.0,  "#3a3a3a")
                                            ctx.fillStyle = base
                                            ctx.fill()
                                            if (hp > 0) {
                                                drawShape()
                                                var teal = ctx.createLinearGradient(0, 0, 0, h)
                                                teal.addColorStop(0,    "#80e0e0")
                                                teal.addColorStop(0.08, "#39c5bb")
                                                teal.addColorStop(0.5,  "#2a8a8a")
                                                teal.addColorStop(1.0,  "#3a6a6a")
                                                ctx.globalAlpha = hp
                                                ctx.fillStyle = teal
                                                ctx.fill()
                                                ctx.globalAlpha = 1.0
                                            }
                                            ctx.beginPath()
                                            ctx.moveTo(cut, 0)
                                            ctx.lineTo(w,   0)
                                            ctx.lineTo(w,   h * 0.62)
                                            ctx.lineTo(0,   h * 0.62)
                                            ctx.lineTo(0,   cut)
                                            ctx.closePath()
                                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                            gloss.addColorStop(0, "rgba(255,255,255," + (0.15 + hp * 0.25) + ")")
                                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                            ctx.fillStyle = gloss
                                            ctx.fill()
                                            ctx.beginPath()
                                            ctx.moveTo(cut, 0.5)
                                            ctx.lineTo(w,   0.5)
                                            ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"
                                            ctx.lineWidth = 1
                                            ctx.stroke()
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.sym
                                        color: lmArea.containsMouse ? "#ffffff" : "#999999"
                                        font.pixelSize: 14
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }

                                    MouseArea {
                                        id: lmArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onContainsMouseChanged: lmCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                        onClicked: parent.activated()
                                    }
                                }

                                LockMediaBtn {
                                    sym: "⏮"
                                    onActivated: if (lockRoot.activePlayer) lockRoot.activePlayer.previous()
                                }
                                LockMediaBtn {
                                    sym: lockRoot.activePlayer && lockRoot.activePlayer.isPlaying ? "⏸" : "⏵"
                                    onActivated: if (lockRoot.activePlayer) lockRoot.activePlayer.togglePlaying()
                                }
                                LockMediaBtn {
                                    sym: "⏭"
                                    onActivated: if (lockRoot.activePlayer) lockRoot.activePlayer.next()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

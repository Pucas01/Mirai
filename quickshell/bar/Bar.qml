import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Io

Variants {
    id: shellRoot
    model: Quickshell.screens

    property var pendingToastNotif: null
    property int globalNotifCount: 0
    property string pendingScreenshotPath: ""
    property int screenshotTrigger: 0

    PanelWindow {
        id: panel
        property var modelData
        screen: modelData

        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property var screenWorkspaces: Hyprland.workspaces.values.filter(w => w.monitor === hyprMonitor)
        property var preferredPlayer: null
        property var activePlayer: {
            var players = Mpris.players.values
            if (preferredPlayer && players.indexOf(preferredPlayer) !== -1) return preferredPlayer
            return players.find(p => p.isPlaying) ?? (players.length > 0 ? players[0] : null)
        }

        NotificationServer {
            id: notifServer
            keepOnReload: true
            onNotification: notif => {
                if (notif.appName === "qs-screenshot") {
                    shellRoot.pendingScreenshotPath = notif.body
                    shellRoot.screenshotTrigger += 1
                    return
                }
                notif.tracked = true
                shellRoot.globalNotifCount += 1
                shellRoot.pendingToastNotif = notif
            }
        }

        Connections {
            target: notifServer.trackedNotifications
            function onRowsRemoved(parent, first, last) { shellRoot.globalNotifCount = Math.max(0, shellRoot.globalNotifCount - (last - first + 1)) }
            function onModelReset() { shellRoot.globalNotifCount = 0 }
        }

        Connections {
            target: shellRoot
            function onScreenshotTriggerChanged() {
                if (!shellRoot.pendingScreenshotPath) return
                if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
                var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
                var barBottom = barBg.mapToGlobal(0, barBg.height)
                screenshotWin.show(
                    wsCenter.x - screenshotWin.width / 2,
                    barBottom.y + 8,
                    shellRoot.pendingScreenshotPath,
                    shellRoot.screenshotTrigger
                )
            }
            function onPendingToastNotifChanged() {
                if (!shellRoot.pendingToastNotif) return
                if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
                var pos = barBg.mapToGlobal(barBg.width - toastWin.width - 16, barBg.height + 8)
                toastWin.show(pos.x, pos.y, shellRoot.pendingToastNotif)
            }
        }

        anchors { top: true; left: true; right: true }
        implicitHeight: 50
        color: "transparent"
        exclusiveZone: 46

        TrayMenu {
            id: trayMenu
        }

        MediaPopup {
            id: mediaPopup
            activePlayer: panel.activePlayer
            preferredPlayer: panel.preferredPlayer
            onPreferredPlayerChanged: panel.preferredPlayer = mediaPopup.preferredPlayer
        }

        ToastWin {
            id: toastWin
        }

        ScreenshotWin {
            id: screenshotWin
        }

        StartMenu {
            id: startMenu
        }

        NotifPopup {
            id: notifPopup
            trackedNotifications: notifServer.trackedNotifications
            notifCount: shellRoot.globalNotifCount
            onNotifCountReset: shellRoot.globalNotifCount = 0
        }

        Rectangle {
            id: barBg
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 46

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0;  color: "#3d3d3d" }
                GradientStop { position: 0.08; color: "#2c2c2c" }
                GradientStop { position: 0.5;  color: "#232323" }
                GradientStop { position: 1.0;  color: "#181818" }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: "#5a5a5a"
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.topMargin: 1
                height: 4
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "#50505050" }
                    GradientStop { position: 1.0; color: "#00000000" }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: "#39c5bb"
            }

            Row {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 14 }
                spacing: 10

                Item {
                    id: bellItem
                    width: 35; height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: bellCanvas
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
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        font.pixelSize: 14
                        color: bellMouseArea.containsMouse ? "#ffffff" : shellRoot.globalNotifCount > 0 ? "#39c5bb" : "#888888"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Rectangle {
                        visible: shellRoot.globalNotifCount > 0
                        anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                        width: 8; height: 8; radius: 4
                        color: "#ff4444"
                    }

                    MouseArea {
                        id: bellMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        onContainsMouseChanged: bellCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            notifPopup.open(center.x - notifPopup.width / 2, barBottom.y + 6)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayDelegate
                            required property var modelData
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: trayDelegate.modelData.icon
                                mipmap: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        trayDelegate.modelData.activate()
                                    } else {
                                        var iconCenter = mapToGlobal(width / 2, 0)
                                        var barBottom = barBg.mapToGlobal(0, barBg.height)
                                        trayMenu.targetItem = trayDelegate.modelData
                                        trayMenu.open(iconCenter.x - trayMenu.width / 2, barBottom.y + 6)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        id: dateText
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#777777"
                        font.pixelSize: 15
                        font.family: "monospace"
                        text: Qt.formatDateTime(new Date(), "ddd dd MMM")
                    }

                    Item {
                        width: 16
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: parent.height * 0.7
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#00404040" }
                                GradientStop { position: 0.4; color: "#804a4a4a" }
                                GradientStop { position: 0.6; color: "#804a4a4a" }
                                GradientStop { position: 1.0; color: "#00404040" }
                            }
                        }
                    }

                    Text {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#d0d0d0"
                        font.pixelSize: 15
                        font.family: "monospace"
                        text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            var now = new Date()
                            clockText.text = Qt.formatDateTime(now, "hh:mm:ss")
                            dateText.text = Qt.formatDateTime(now, "ddd dd MMM")
                        }
                    }
                }
            }

            Row {
                anchors { right: wsArea.left; top: parent.top; bottom: parent.bottom }
                spacing: 0
                visible: panel.activePlayer !== null

                Item {
                    id: mediaWidget
                    width: mediaRow.width + 16
                    height: parent.height

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var center = mapToGlobal(width / 2, 0)
                            var barBottom = barBg.mapToGlobal(0, barBg.height)
                            mediaPopup.open(center.x - mediaPopup.width / 2, barBottom.y + 6)
                        }
                    }

                    Row {
                        id: mediaRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#111111"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: panel.activePlayer ? panel.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: panel.activePlayer && panel.activePlayer.trackArtUrl !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !panel.activePlayer || panel.activePlayer.trackArtUrl === ""
                                text: "♪"
                                color: "#39c5bb"
                                font.pixelSize: 14
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: 140
                                text: panel.activePlayer ? panel.activePlayer.trackTitle : ""
                                color: "#d0d0d0"
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 140
                                text: panel.activePlayer ? panel.activePlayer.trackArtist : ""
                                color: "#666666"
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

            }

            Item {
                id: wsArea
                anchors.centerIn: parent
                width: wsRow.width + 48
                height: parent.height

                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 1
                    height: parent.height * 0.5
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 1
                    height: parent.height * 0.5
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00404040" }
                        GradientStop { position: 0.4; color: "#804a4a4a" }
                        GradientStop { position: 0.6; color: "#804a4a4a" }
                        GradientStop { position: 1.0; color: "#00404040" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onWheel: wheel => {
                        const ws = panel.screenWorkspaces
                        const activeIdx = ws.findIndex(w => w.active)
                        if (activeIdx === -1) return
                        const dir = wheel.angleDelta.y > 0 ? 1 : -1
                        const nextId = ws[(activeIdx + dir + ws.length) % ws.length].id
                        Hyprland.dispatch("hl.dsp.focus({workspace=\"" + nextId + "\"})")
                    }
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 5

                Repeater {
                    model: panel.screenWorkspaces

                    delegate: Item {
                        required property var modelData

                        property var toplevels: modelData.toplevels.values
                        property bool occupied: toplevels.length > 0
                        property var activeToplevel: toplevels.find(t => t.activated) || toplevels[0] || null
                        property string appId: {
                            if (!activeToplevel) return ""
                            if (activeToplevel.wayland && activeToplevel.wayland.appId !== "")
                                return activeToplevel.wayland.appId
                            if (activeToplevel.lastIpcObject)
                                return activeToplevel.lastIpcObject["class"] || ""
                            return ""
                        }
                        property var appEntry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null

                        width: occupied ? 34 : (modelData.active ? 24 : 10)
                        height: 28

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Canvas {
                            id: pill
                            anchors.fill: parent
                            visible: parent.occupied

                            property bool active: modelData.active
                            property real activeProgress: active ? 1.0 : 0.0
                            Behavior on activeProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            property real hoverProgress: 0.0
                            Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onActiveProgressChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()
                            onHoverProgressChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var cut = 6
                                var w = width
                                var h = height
                                var ap = activeProgress
                                var hp = hoverProgress
                                var tealAmount = Math.max(ap, hp * (1.0 - ap))

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

                                if (tealAmount > 0) {
                                    drawShape()
                                    var teal = ctx.createLinearGradient(0, 0, 0, h)
                                    teal.addColorStop(0,    "#80e0e0")
                                    teal.addColorStop(0.08, "#39c5bb")
                                    teal.addColorStop(0.5,  "#2a8a8a")
                                    teal.addColorStop(1.0,  "#3a6a6a")
                                    ctx.globalAlpha = tealAmount
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
                                gloss.addColorStop(0, "rgba(255,255,255," + (0.30 + tealAmount * 0.24) + ")")
                                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss
                                ctx.fill()

                                ctx.beginPath()
                                ctx.moveTo(cut, 0.5)
                                ctx.lineTo(w,   0.5)
                                ctx.strokeStyle = tealAmount > 0.5 ? "#c0f4f4" : "#646464"
                                ctx.lineWidth = 1
                                ctx.stroke()
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            mipmap: true
                            visible: occupied && appEntry !== null && appEntry.icon !== ""
                            source: appEntry && appEntry.icon !== "" ? "image://icon/" + appEntry.icon : ""
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: modelData.active ? 8 : 5
                            height: modelData.active ? 8 : 5
                            radius: height / 2
                            color: modelData.active ? "#39c5bb" : "#484848"
                            visible: !occupied
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onContainsMouseChanged: pill.hoverProgress = containsMouse ? 1.0 : 0.0
                            onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=\"" + modelData.id + "\"})")
                            onWheel: wheel => { wheel.accepted = false }
                        }
                    }
                }
                }
            }
        }

        Item {
            id: startBtn
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 100

            Canvas {
                id: startBtnCanvas
                anchors.fill: parent
                property real hoverProgress: 0.0
                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHoverProgressChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var slant = 24, w = width, h = height, hp = hoverProgress
                    function drawShape() {
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(w, 0)
                        ctx.lineTo(w - slant, h)
                        ctx.lineTo(0, h)
                        ctx.closePath()
                    }
                    drawShape()
                    var base = ctx.createLinearGradient(0, 0, 0, h)
                    base.addColorStop(0,    "#3d3d3d")
                    base.addColorStop(0.08, "#2a2a2a")
                    base.addColorStop(0.5,  "#303030")
                    base.addColorStop(1.0,  "#3a3a3a")
                    ctx.fillStyle = base; ctx.fill()
                    if (hp > 0) {
                        drawShape()
                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                        teal.addColorStop(0,    "#80e0e0")
                        teal.addColorStop(0.08, "#39c5bb")
                        teal.addColorStop(0.5,  "#2a8a8a")
                        teal.addColorStop(1.0,  "#3a6a6a")
                        ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                    }
                    ctx.save()
                    drawShape()
                    ctx.clip()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                    gloss.addColorStop(0, "rgba(255,255,255," + (0.22 + hp * 0.18) + ")")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss
                    ctx.fillRect(0, 0, w, h * 0.55)
                    ctx.restore()
                    ctx.beginPath()
                    ctx.moveTo(0, 0.5)
                    ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -5
                anchors.horizontalCenterOffset: -8
                text: "󰣇"
                font.pixelSize: 18
                color: startBtnArea.containsMouse ? "#ffffff" : "#39c5bb"
                Behavior on color { ColorAnimation { duration: 130 } }
            }

            MouseArea {
                id: startBtnArea
                anchors { left: parent.left; top: parent.top; right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
                hoverEnabled: true
                onContainsMouseChanged: startBtnCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                onClicked: {
                    var pos = barBg.mapToGlobal(0, barBg.height)
                    startMenu.open(pos.x, pos.y + 6)
                }
            }
        }
    }
}

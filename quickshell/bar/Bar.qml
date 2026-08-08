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
                screenshotWin.imagePath = shellRoot.pendingScreenshotPath
                screenshotWin.saved = false
                screenshotWin.copied = false
                var wsCenter = wsArea.mapToGlobal(wsArea.width / 2, 0)
                var barBottom = barBg.mapToGlobal(0, barBg.height)
                screenshotWin.x = wsCenter.x - screenshotWin.width / 2
                screenshotWin.y = barBottom.y + 8
                screenshotWin.isOpen = false
                screenshotWin.visible = true
                ssOpenTimer.start()
            }
            function onPendingToastNotifChanged() {
                if (!shellRoot.pendingToastNotif) return
                if (!panel.hyprMonitor || !panel.hyprMonitor.focused) return
                toastWin.currentNotif = shellRoot.pendingToastNotif
                toastSwipeItem.swipeX = 0
                var pos = barBg.mapToGlobal(barBg.width - toastWin.width - 16, barBg.height + 8)
                toastWin.x = pos.x
                toastWin.y = pos.y
                toastWin.isOpen = false
                toastWin.visible = true
                toastOpenTimer.start()
                toastAutoClose.restart()
            }
        }

        anchors { top: true; left: true; right: true }
        implicitHeight: 46
        color: "transparent"
        exclusiveZone: implicitHeight

        Window {
            id: trayMenuWin
            property var targetItem: null
            property bool isOpen: false
            flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 180
            height: menuCol.implicitHeight + 2
            visible: false

            function closeMenu() {
                isOpen = false
                closeTimer.start()
            }

            onClosing: close => {
                if (isOpen) {
                    close.accepted = false
                    closeMenu()
                }
            }

            Timer {
                id: openTimer
                interval: 10
                onTriggered: trayMenuWin.isOpen = true
            }

            Timer {
                id: closeTimer
                interval: 220
                onTriggered: trayMenuWin.visible = false
            }

            QsMenuOpener {
                id: menuOpener
                menu: trayMenuWin.targetItem ? trayMenuWin.targetItem.menu : null
            }

            Rectangle {
                id: menuRect
                anchors.fill: parent
                color: "#cc1a1a1a"
                border.color: "#39c5bb"
                border.width: 1

                opacity: trayMenuWin.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real scaleVal: trayMenuWin.isOpen ? 1.0 : 0.88
                Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                property real slideY: trayMenuWin.isOpen ? 0 : -8
                Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                transform: [
                    Scale { origin.x: menuRect.width / 2; origin.y: 0; xScale: menuRect.scaleVal; yScale: menuRect.scaleVal },
                    Translate { y: menuRect.slideY }
                ]

                Column {
                    id: menuCol
                    width: parent.width - 2
                    x: 1
                    y: 5
                    bottomPadding: 5

                    Column {
                        width: parent.width
                        spacing: 3
                        topPadding: 5
                        bottomPadding: 5

                        Repeater {
                            model: menuOpener.children

                            delegate: Item {
                                required property var modelData
                                width: menuCol.width
                                height: modelData.isSeparator ? 8 : 30

                                Rectangle {
                                    visible: modelData.isSeparator
                                    anchors.centerIn: parent
                                    width: parent.width - 20
                                    height: 1
                                    color: "#39c5bb"
                                    opacity: 0.15
                                }

                                Item {
                                    visible: !modelData.isSeparator
                                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }

                                    Canvas {
                                        id: entryCanvas
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
                                            gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
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
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 10
                                        text: modelData.text
                                        color: !modelData.enabled ? "#444444" : entryArea.containsMouse ? "#ffffff" : "#e0e0e0"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                        font.pixelSize: 12
                                        font.family: "monospace"
                                        elide: Text.ElideRight
                                        width: parent.width - 20
                                    }

                                    MouseArea {
                                        id: entryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: modelData.enabled
                                        onContainsMouseChanged: entryCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                        onClicked: {
                                            modelData.triggered()
                                            trayMenuWin.closeMenu()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Window {
            id: mediaPopup
            property bool isOpen: false
            property var displayPlayer: panel.activePlayer
            flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 260
            height: 400
            visible: false

            function closePopup() {
                isOpen = false
                mediaCloseTimer.start()
            }

            onClosing: close => {
                if (isOpen) {
                    close.accepted = false
                    closePopup()
                }
            }

            Connections {
                target: panel
                function onActivePlayerChanged() {
                    if (panel.activePlayer === mediaPopup.displayPlayer) return
                    playerFadeOut.start()
                }
            }

            SequentialAnimation {
                id: playerFadeOut
                NumberAnimation { target: mediaContent; property: "opacity"; to: 0; duration: 130; easing.type: Easing.OutCubic }
                ScriptAction { script: { mediaPopup.displayPlayer = panel.activePlayer } }
                NumberAnimation { target: mediaContent; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }

            Timer { id: mediaOpenTimer; interval: 10; onTriggered: mediaPopup.isOpen = true }
            Timer { id: mediaCloseTimer; interval: 220; onTriggered: mediaPopup.visible = false }

            Rectangle {
                id: mediaRect
                anchors.fill: parent
                color: "#1a1a1a"
                border.color: "#39c5bb"
                border.width: 1

                opacity: mediaPopup.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real scaleVal: mediaPopup.isOpen ? 1.0 : 0.88
                Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                property real slideY: mediaPopup.isOpen ? 0 : -12
                Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                transform: [
                    Scale { origin.x: mediaRect.width / 2; origin.y: 0; xScale: mediaRect.scaleVal; yScale: mediaRect.scaleVal },
                    Translate { y: mediaRect.slideY }
                ]

                Column {
                    id: mediaContent
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    Rectangle {
                        width: parent.width
                        height: width
                        color: "#111111"

                        Image {
                            anchors.fill: parent
                            source: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: mediaPopup.displayPlayer && mediaPopup.displayPlayer.trackArtUrl !== ""
                        }

                        Rectangle {
                            visible: !mediaPopup.displayPlayer || mediaPopup.displayPlayer.trackArtUrl === ""
                            anchors.fill: parent
                            color: "#111111"
                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: "#39c5bb"
                                font.pixelSize: 48
                            }
                        }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 48
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#00000000" }
                                GradientStop { position: 1.0; color: "#cc1a1a1a" }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - parent.width
                        color: "#1a1a1a"

                        Column {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            anchors.margins: 14
                            anchors.topMargin: 10
                            spacing: 3

                            Text {
                                width: parent.width
                                text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackTitle : ""
                                color: "#e0e0e0"
                                font.pixelSize: 14
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.trackArtist : ""
                                color: "#777777"
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Mpris.players.values.length > 1 ? 46 : 16 }
                            spacing: 12

                            component MediaBtn: Item {
                                width: 52
                                height: 36
                                property string sym: ""
                                signal activated()

                                Canvas {
                                    id: btnCanvas
                                    anchors.fill: parent
                                    property real hoverProgress: 0.0
                                    Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    onHoverProgressChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cut = 6, w = width, h = height, hp = hoverProgress
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
                                    color: btnArea.containsMouse ? "#ffffff" : "#999999"
                                    font.pixelSize: 15
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }

                                MouseArea {
                                    id: btnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: btnCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                    onClicked: parent.activated()
                                }
                            }

                            MediaBtn {
                                sym: "⏮"
                                onActivated: if (panel.activePlayer) panel.activePlayer.previous()
                            }
                            MediaBtn {
                                sym: panel.activePlayer && panel.activePlayer.isPlaying ? "⏸" : "⏵"
                                onActivated: if (panel.activePlayer) panel.activePlayer.togglePlaying()
                            }
                            MediaBtn {
                                sym: "⏭"
                                onActivated: if (panel.activePlayer) panel.activePlayer.next()
                            }
                        }

                        Item {
                            visible: Mpris.players.values.length > 1
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10; leftMargin: 14; rightMargin: 14 }
                            height: 28

                            Canvas {
                                id: playerCycleCanvas
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
                                    ctx.beginPath(); ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                    gloss.addColorStop(0, "rgba(255,255,255," + (0.10 + hp * 0.18) + ")")
                                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                                    ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⇄"
                                    color: playerCycleArea.containsMouse ? "#ffffff" : "#888888"
                                    font.pixelSize: 11
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mediaPopup.displayPlayer ? mediaPopup.displayPlayer.identity : ""
                                    color: playerCycleArea.containsMouse ? "#dddddd" : "#666666"
                                    font.pixelSize: 10; font.family: "monospace"
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                            }

                            MouseArea {
                                id: playerCycleArea
                                anchors.fill: parent; hoverEnabled: true
                                onContainsMouseChanged: playerCycleCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    var players = Mpris.players.values
                                    if (players.length < 2) return
                                    var idx = players.indexOf(panel.activePlayer)
                                    panel.preferredPlayer = players[(idx + 1) % players.length]
                                }
                            }
                        }
                    }
                }
            }
        }

        Window {
            id: toastWin
            property bool isOpen: false
            property var currentNotif: null
            flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 320
            height: 78
            visible: false

            Timer { id: toastOpenTimer; interval: 10; onTriggered: toastWin.isOpen = true }
            Timer { id: toastAutoClose; interval: 4000; onTriggered: { toastWin.isOpen = false; toastHideTimer.start() } }
            Timer { id: toastHideTimer; interval: 220; onTriggered: toastWin.visible = false }

            Item {
                id: toastAnimItem
                anchors.fill: parent

                opacity: toastWin.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real scaleVal: toastWin.isOpen ? 1.0 : 0.88
                Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                property real slideY: toastWin.isOpen ? 0 : -10
                Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                transform: [
                    Scale { origin.x: toastAnimItem.width / 2; origin.y: 0; xScale: toastAnimItem.scaleVal; yScale: toastAnimItem.scaleVal },
                    Translate { y: toastAnimItem.slideY }
                ]

                Item {
                    id: toastSwipeItem
                    width: parent.width
                    height: parent.height
                    x: swipeX
                    opacity: Math.max(0, 1.0 - swipeX / 150)

                    property real swipeX: 0

                    Canvas {
                        id: toastCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 8, w = width, h = height

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

                            ctx.beginPath()
                            ctx.moveTo(cut, 0)
                            ctx.lineTo(w,   0)
                            ctx.lineTo(w,   h * 0.55)
                            ctx.lineTo(0,   h * 0.55)
                            ctx.lineTo(0,   cut)
                            ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
                            gloss.addColorStop(0, "rgba(255,255,255,0.18)")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss
                            ctx.fill()

                            ctx.beginPath()
                            ctx.moveTo(cut, 0.5)
                            ctx.lineTo(w,   0.5)
                            ctx.strokeStyle = "#646464"
                            ctx.lineWidth = 1
                            ctx.stroke()
                        }
                    }

                    Row {
                        anchors { left: parent.left; right: toastCloseItem.left; top: parent.top; bottom: parent.bottom; margins: 12; rightMargin: 4 }
                        spacing: 10

                        IconImage {
                            width: 24; height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            source: toastWin.currentNotif && toastWin.currentNotif.appIcon !== "" ? "image://icon/" + toastWin.currentNotif.appIcon : ""
                            mipmap: true
                            visible: toastWin.currentNotif && toastWin.currentNotif.appIcon !== ""
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (toastWin.currentNotif && toastWin.currentNotif.appIcon !== "" ? 34 : 0)
                            spacing: 4

                            Text {
                                width: parent.width
                                text: toastWin.currentNotif ? toastWin.currentNotif.summary : ""
                                color: "#e0e0e0"
                                font.pixelSize: 13; font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: toastWin.currentNotif ? toastWin.currentNotif.body : ""
                                color: "#777777"
                                font.pixelSize: 11; font.family: "monospace"
                                elide: Text.ElideRight
                                visible: toastWin.currentNotif && toastWin.currentNotif.body !== ""
                            }
                        }
                    }

                    Item {
                        id: toastCloseItem
                        anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 8 }
                        width: 16; height: 16

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: toastCloseArea.containsMouse ? "#ffffff" : "#555555"
                            font.pixelSize: 14
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: toastCloseArea
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: { toastWin.isOpen = false; toastHideTimer.start() }
                        }
                    }
                }

                DragHandler {
                    id: toastSwipe
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onTranslationChanged: if (active) toastSwipeItem.swipeX = Math.max(0, translation.x)
                    onActiveChanged: {
                        if (!active) {
                            if (toastSwipeItem.swipeX > 80) {
                                if (toastWin.currentNotif) toastWin.currentNotif.dismiss()
                                toastWin.isOpen = false
                                toastHideTimer.start()
                            } else {
                                toastSnapBackAnim.start()
                            }
                        }
                    }
                }

                NumberAnimation {
                    id: toastSnapBackAnim
                    target: toastSwipeItem
                    property: "swipeX"
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }

        Window {
            id: screenshotWin
            property bool isOpen: false
            property string imagePath: ""
            property bool copied: false
            property bool saved: false
            flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 310
            height: 240
            visible: false

            Timer { id: ssOpenTimer; interval: 10; onTriggered: screenshotWin.isOpen = true }
            Timer { id: ssHideTimer; interval: 220; onTriggered: screenshotWin.visible = false }

            Process {
                id: copyProc
                command: ["bash", "-c", "wl-copy < " + screenshotWin.imagePath]
                onExited: code => {
                    if (code === 0) {
                        screenshotWin.copied = true
                        ssCopyCloseTimer.start()
                    }
                }
            }

            Timer { id: ssCopyCloseTimer; interval: 600; onTriggered: { screenshotWin.isOpen = false; ssHideTimer.start() } }

            Process {
                id: saveProc
                property string dest: ""
                command: ["bash", "-c", "mkdir -p ~/Pictures/Screenshots && cp " + screenshotWin.imagePath + " " + dest]
                onExited: code => {
                    if (code === 0) {
                        screenshotWin.saved = true
                        ssSaveCloseTimer.start()
                    }
                }
            }

            Timer { id: ssSaveCloseTimer; interval: 600; onTriggered: { screenshotWin.isOpen = false; ssHideTimer.start() } }

            Rectangle {
                id: ssRect
                anchors.fill: parent
                color: "#1a1a1a"
                border.color: "#39c5bb"
                border.width: 1

                opacity: screenshotWin.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real scaleVal: screenshotWin.isOpen ? 1.0 : 0.88
                Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                property real slideY: screenshotWin.isOpen ? 0 : -10
                Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                transform: [
                    Scale { origin.x: ssRect.width / 2; origin.y: 0; xScale: ssRect.scaleVal; yScale: ssRect.scaleVal },
                    Translate { y: ssRect.slideY }
                ]

                Column {
                    anchors { fill: parent; margins: 8 }
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 182
                        color: "#111111"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: screenshotWin.imagePath !== "" ? ("file://" + screenshotWin.imagePath + "?t=" + shellRoot.screenshotTrigger) : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        component SsBtn: Item {
                            property string label: ""
                            property bool active: false
                            signal clicked()
                            width: (parent.width - 12) / 3
                            height: 30

                            Canvas {
                                id: ssBtnCanvas
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
                                        ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h-cut)
                                        ctx.lineTo(w-cut,h); ctx.lineTo(0,h); ctx.lineTo(0,cut); ctx.closePath()
                                    }
                                    drawShape()
                                    var base = ctx.createLinearGradient(0,0,0,h)
                                    base.addColorStop(0,"#3d3d3d"); base.addColorStop(0.08,"#2a2a2a")
                                    base.addColorStop(0.5,"#303030"); base.addColorStop(1.0,"#3a3a3a")
                                    ctx.fillStyle = base; ctx.fill()
                                    if (ta > 0) {
                                        drawShape()
                                        var teal = ctx.createLinearGradient(0,0,0,h)
                                        teal.addColorStop(0,"#80e0e0"); teal.addColorStop(0.08,"#39c5bb")
                                        teal.addColorStop(0.5,"#2a8a8a"); teal.addColorStop(1.0,"#3a6a6a")
                                        ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                                    }
                                    ctx.beginPath(); ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h*0.62)
                                    ctx.lineTo(0,h*0.62); ctx.lineTo(0,cut); ctx.closePath()
                                    var gloss = ctx.createLinearGradient(0,0,0,h*0.62)
                                    gloss.addColorStop(0,"rgba(255,255,255,"+(0.12+ta*0.2)+")")
                                    gloss.addColorStop(1,"rgba(255,255,255,0.00)")
                                    ctx.fillStyle = gloss; ctx.fill()
                                    ctx.beginPath(); ctx.moveTo(cut,0.5); ctx.lineTo(w,0.5)
                                    ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.label
                                color: ssBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
                                font.pixelSize: 10; font.family: "monospace"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: ssBtnArea
                                anchors.fill: parent; hoverEnabled: true
                                onContainsMouseChanged: ssBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                                onClicked: parent.clicked()
                            }
                        }

                        SsBtn {
                            label: screenshotWin.copied ? "copied!" : "copy"
                            active: screenshotWin.copied
                            onClicked: { copyProc.running = false; copyProc.running = true }
                        }
                        SsBtn {
                            label: screenshotWin.saved ? "saved!" : "save"
                            active: screenshotWin.saved
                            onClicked: {
                                if (screenshotWin.saved) return
                                var now = new Date()
                                var ts = now.getFullYear() + "" +
                                    String(now.getMonth()+1).padStart(2,"0") +
                                    String(now.getDate()).padStart(2,"0") + "_" +
                                    String(now.getHours()).padStart(2,"0") +
                                    String(now.getMinutes()).padStart(2,"0") +
                                    String(now.getSeconds()).padStart(2,"0")
                                saveProc.dest = "~/Pictures/Screenshots/screenshot_" + ts + ".png"
                                saveProc.running = false
                                saveProc.running = true
                            }
                        }
                        SsBtn {
                            label: "discard"
                            onClicked: { screenshotWin.isOpen = false; ssHideTimer.start() }
                        }
                    }
                }
            }
        }

        Window {
            id: notifPopup
            property bool isOpen: false
            flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 320
            height: 400
            visible: false

            function closePopup() { isOpen = false; notifCloseTimer.start() }
            onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

            Timer { id: notifOpenTimer; interval: 10; onTriggered: notifPopup.isOpen = true }
            Timer { id: notifCloseTimer; interval: 220; onTriggered: notifPopup.visible = false }

            Rectangle {
                id: notifRect
                anchors.fill: parent
                color: "#1a1a1a"
                border.color: "#39c5bb"
                border.width: 1

                opacity: notifPopup.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real scaleVal: notifPopup.isOpen ? 1.0 : 0.88
                Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

                property real slideY: notifPopup.isOpen ? 0 : -8
                Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                transform: [
                    Scale { origin.x: notifRect.width / 2; origin.y: 0; xScale: notifRect.scaleVal; yScale: notifRect.scaleVal },
                    Translate { y: notifRect.slideY }
                ]

                Column {
                    anchors { fill: parent; margins: 1 }
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 36

                        Item {
                            id: clearAllBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                            width: 58; height: 22
                            visible: shellRoot.globalNotifCount > 0

                            Canvas {
                                id: clearAllCanvas
                                anchors.fill: parent
                                property real hoverProgress: 0.0
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cut = 4, w = width, h = height, hp = hoverProgress
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
                                text: "clear all"
                                color: clearAllArea.containsMouse ? "#ffffff" : "#999999"
                                font.pixelSize: 9; font.family: "monospace"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                            MouseArea {
                                id: clearAllArea
                                anchors.fill: parent; hoverEnabled: true
                                onContainsMouseChanged: clearAllCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    var notifs = notifServer.trackedNotifications.values
                                    for (var i = notifs.length - 1; i >= 0; i--) notifs[i].dismiss()
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 50
                        visible: shellRoot.globalNotifCount === 0
                        Text {
                            anchors.centerIn: parent
                            text: "no notifications"
                            color: "#444444"; font.pixelSize: 11; font.family: "monospace"
                        }
                    }

                    ListView {
                        id: notifListView
                        width: parent.width
                        height: parent.height - 37
                        clip: true
                        visible: shellRoot.globalNotifCount > 0
                        model: notifServer.trackedNotifications
                        spacing: 3
                        topMargin: 5
                        bottomMargin: 5

                        removeDisplaced: Transition {
                            NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: notifDelegate
                            required property var modelData
                            width: notifListView.width
                                    height: 66
                                    clip: true

                                    Item {
                                        id: swipeItem
                                        anchors { top: parent.top; bottom: parent.bottom }
                                        width: parent.width - 8
                                        x: swipeOffset + 4
                                        opacity: Math.max(0, 1.0 - swipeOffset / 120)

                                        property real swipeOffset: 0

                                        Canvas {
                                            id: notifCanvas
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

                                        Row {
                                            anchors { left: parent.left; right: dismissItem.left; top: parent.top; bottom: parent.bottom; margins: 10; rightMargin: 4 }
                                            spacing: 8

                                            IconImage {
                                                width: 22; height: 22
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: modelData.appIcon !== "" ? "image://icon/" + modelData.appIcon : ""
                                                mipmap: true
                                                visible: modelData.appIcon !== ""
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - (modelData.appIcon !== "" ? 30 : 0)
                                                spacing: 4

                                                Text {
                                                    width: parent.width
                                                    text: modelData.summary
                                                    color: notifItemArea.containsMouse ? "#ffffff" : "#d0d0d0"
                                                    font.pixelSize: 12; font.family: "monospace"
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 130 } }
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: modelData.body
                                                    color: notifItemArea.containsMouse ? "#bbbbbb" : "#666666"
                                                    font.pixelSize: 10; font.family: "monospace"
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.Wrap
                                                    visible: modelData.body !== ""
                                                    Behavior on color { ColorAnimation { duration: 130 } }
                                                }
                                            }
                                        }

                                        Item {
                                            id: dismissItem
                                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                                            width: 20; height: 20; z: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: dismissArea.containsMouse ? "#ffffff" : "#555555"
                                                font.pixelSize: 16
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                id: dismissArea
                                                anchors.fill: parent; hoverEnabled: true
                                                onClicked: modelData.dismiss()
                                            }
                                        }

                                        MouseArea {
                                            id: notifItemArea
                                            anchors.fill: parent; hoverEnabled: true
                                            onContainsMouseChanged: notifCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                        }
                                    }

                                    DragHandler {
                                        id: notifSwipe
                                        xAxis.enabled: true
                                        xAxis.minimum: 0
                                        yAxis.enabled: false
                                        onTranslationChanged: if (active) swipeItem.swipeOffset = Math.max(0, translation.x)
                                        onActiveChanged: {
                                            if (!active) {
                                                if (swipeItem.swipeOffset > 80) notifDelegate.modelData.dismiss()
                                                else snapBackAnim.start()
                                            }
                                        }
                                    }

                                    NumberAnimation {
                                        id: snapBackAnim
                                        target: swipeItem
                                        property: "swipeOffset"
                                        to: 0
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                }
                    }
                }
            }
        }

        Rectangle {
            id: barBg
            anchors.fill: parent

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
                            notifPopup.x = center.x - notifPopup.width / 2
                            notifPopup.y = barBottom.y + 6
                            notifPopup.isOpen = false
                            notifPopup.visible = true
                            notifOpenTimer.start()
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
                                        trayMenuWin.targetItem = trayDelegate.modelData
                                        trayMenuWin.x = iconCenter.x - trayMenuWin.width / 2
                                        trayMenuWin.y = barBottom.y + 6
                                        trayMenuWin.isOpen = false
                                        trayMenuWin.visible = true
                                        openTimer.start()
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
                            mediaPopup.x = center.x - mediaPopup.width / 2
                            mediaPopup.y = barBottom.y + 6
                            mediaPopup.isOpen = false
                            mediaPopup.visible = true
                            mediaOpenTimer.start()
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
    }
}

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: panel
        property var modelData
        screen: modelData

        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property var screenWorkspaces: Hyprland.workspaces.values.filter(w => w.monitor === hyprMonitor)
        property var activePlayer: Mpris.players.values.find(p => p.isPlaying) ?? (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null)

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
            flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            width: 260
            height: 370
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
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    Rectangle {
                        width: parent.width
                        height: width
                        color: "#111111"

                        Image {
                            anchors.fill: parent
                            source: panel.activePlayer ? panel.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: panel.activePlayer && panel.activePlayer.trackArtUrl !== ""
                        }

                        Rectangle {
                            visible: !panel.activePlayer || panel.activePlayer.trackArtUrl === ""
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
                                text: panel.activePlayer ? panel.activePlayer.trackTitle : ""
                                color: "#e0e0e0"
                                font.pixelSize: 14
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: panel.activePlayer ? panel.activePlayer.trackArtist : ""
                                color: "#777777"
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
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

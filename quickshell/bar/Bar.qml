import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: panel
        property var modelData
        screen: modelData

        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property var screenWorkspaces: Hyprland.workspaces.values.filter(w => w.monitor === hyprMonitor)

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
                interval: 160
                onTriggered: trayMenuWin.visible = false
            }

            QsMenuOpener {
                id: menuOpener
                menu: trayMenuWin.targetItem ? trayMenuWin.targetItem.menu : null
            }

            Rectangle {
                id: menuRect
                anchors.fill: parent
                color: "#1e1e1e"
                border.color: "#39c5bb"
                border.width: 1
                opacity: trayMenuWin.isOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                property real slideY: trayMenuWin.isOpen ? 0 : -8
                Behavior on slideY { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                transform: Translate { y: menuRect.slideY }

                Column {
                    id: menuCol
                    width: parent.width - 2
                    x: 1
                    y: 1

                    Rectangle {
                        width: parent.width
                        height: 26
                        color: "#151515"

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            text: trayMenuWin.targetItem ? (trayMenuWin.targetItem.tooltip || trayMenuWin.targetItem.title || "") : ""
                            color: "#39c5bb"
                            font.pixelSize: 11
                            font.family: "monospace"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#39c5bb"
                        opacity: 0.3
                    }

                    Repeater {
                        model: menuOpener.children

                        delegate: Item {
                            required property var modelData
                            width: menuCol.width
                            height: modelData.isSeparator ? 9 : 30

                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 20
                                height: 1
                                color: "#3a3a3a"
                            }

                            Rectangle {
                                visible: !modelData.isSeparator
                                anchors.fill: parent
                                color: entryHover.containsMouse && modelData.enabled ? "#2a3a3a" : "transparent"

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 10
                                    text: modelData.text
                                    color: !modelData.enabled ? "#555555" : entryHover.containsMouse ? "#39c5bb" : "#d0d0d0"
                                    font.pixelSize: 12
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                    width: parent.width - 20
                                }

                                MouseArea {
                                    id: entryHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData.enabled
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
                height: 2
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
                            onActiveChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var cut = 6
                                var w = width
                                var h = height
                                var isActive = active

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
                                if (isActive) {
                                    base.addColorStop(0,    "#80e0e0")
                                    base.addColorStop(0.08, "#39c5bb")
                                    base.addColorStop(0.5,  "#2a8a8a")
                                    base.addColorStop(1.0,  "#3a6a6a")
                                } else {
                                    base.addColorStop(0,    "#3d3d3d")
                                    base.addColorStop(0.08, "#2a2a2a")
                                    base.addColorStop(0.5,  "#303030")
                                    base.addColorStop(1.0,  "#3a3a3a")
                                }
                                ctx.fillStyle = base
                                ctx.fill()

                                ctx.beginPath()
                                ctx.moveTo(cut, 0)
                                ctx.lineTo(w,   0)
                                ctx.lineTo(w,   h * 0.62)
                                ctx.lineTo(0,   h * 0.62)
                                ctx.lineTo(0,   cut)
                                ctx.closePath()
                                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                                gloss.addColorStop(0, isActive ? "rgba(255,255,255,0.54)" : "rgba(255,255,255,0.30)")
                                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                                ctx.fillStyle = gloss
                                ctx.fill()

                                ctx.beginPath()
                                ctx.moveTo(cut, 0.5)
                                ctx.lineTo(w,   0.5)
                                ctx.strokeStyle = isActive ? "#c0f4f4" : "#646464"
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

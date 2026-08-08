import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: panel
        property var modelData
        screen: modelData

        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property var screenWorkspaces: Hyprland.workspaces.values.filter(w => w.monitor === hyprMonitor)

        anchors { top: true; left: true; right: true }
        implicitHeight: 40
        color: "transparent"
        exclusiveZone: implicitHeight

        Rectangle {
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

                        width: occupied ? 28 : (modelData.active ? 20 : 8)
                        height: 24

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

                                var cut = 5
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
                            width: 16
                            height: 16
                            mipmap: true
                            visible: occupied && appEntry !== null && appEntry.icon !== ""
                            source: appEntry && appEntry.icon !== "" ? "image://icon/" + appEntry.icon : ""
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: modelData.active ? 6 : 4
                            height: modelData.active ? 6 : 4
                            radius: height / 2
                            color: modelData.active ? "#39c5bb" : "#484848"
                            visible: !occupied
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=\"" + modelData.id + "\"})")
                        }
                    }
                }
            }
        }
    }
}

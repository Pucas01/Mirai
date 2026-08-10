import QtQuick
import Quickshell

Window {
    id: batteryPopup
    property bool isOpen: false
    property int percent: 100
    property string status: ""
    property bool profilesAvailable: false
    property var profiles: []
    property string activeProfile: ""
    property var glyphFn: function(name) { return "󰗑" }
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 260
    height: profilesAvailable ? 128 : 80
    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    visible: false

    signal profileSelected(string name)

    function open(x, y) {
        batteryPopup.x = x
        batteryPopup.y = y
        isOpen = false
        visible = true
        batteryOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        batteryCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: batteryOpenTimer; interval: 10; onTriggered: batteryPopup.isOpen = true }
    Timer { id: batteryCloseTimer; interval: 220; onTriggered: batteryPopup.visible = false }

    function profileLabel(name) {
        return name.split("-").map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1) }).join(" ")
    }

    PanelBackground {
        id: batteryRect
        anchors.fill: parent

        opacity: batteryPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: batteryPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: batteryPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: batteryRect.width / 2; origin.y: 0; xScale: batteryRect.scaleVal; yScale: batteryRect.scaleVal },
            Translate { y: batteryRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 60

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: "󰁹"
                    color: batteryPopup.status === "Charging" ? "#39c5bb" : (batteryPopup.percent <= 15 ? "#ff6b6b" : "#999999")
                    font.pixelSize: 22
                }

                Column {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 46 }
                    spacing: 2

                    Text {
                        text: batteryPopup.percent + "%"
                        color: "#e0e0e0"
                        font.pixelSize: 15; font.family: "monospace"
                    }

                    Text {
                        text: batteryPopup.status !== "" ? batteryPopup.status : "unknown"
                        color: "#777777"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }
            }

            Item { width: 1; height: 8; visible: batteryPopup.profilesAvailable }

            Row {
                visible: batteryPopup.profilesAvailable
                anchors { horizontalCenter: parent.horizontalCenter }
                spacing: 6

                Repeater {
                    model: batteryPopup.profiles

                    delegate: Item {
                        id: profileBtn
                        required property var modelData
                        property bool active: profileBtn.modelData === batteryPopup.activeProfile
                        width: 78; height: 52

                        Canvas {
                            id: profileCanvas
                            anchors.fill: parent
                            property real hp: 0.0
                            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onHpChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            Connections {
                                target: profileBtn
                                function onActiveChanged() { profileCanvas.requestPaint() }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cut = 6, w = width, h = height, ta = profileBtn.active ? 1.0 : profileCanvas.hp
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

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: batteryPopup.glyphFn(profileBtn.modelData)
                                color: profileBtn.active || profileArea.containsMouse ? "#ffffff" : "#999999"
                                font.pixelSize: 15
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: batteryPopup.profileLabel(profileBtn.modelData)
                                color: profileBtn.active || profileArea.containsMouse ? "#ffffff" : "#888888"
                                font.pixelSize: 9; font.family: "monospace"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: profileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: profileCanvas.hp = containsMouse ? 1.0 : 0.0
                            onClicked: batteryPopup.profileSelected(profileBtn.modelData)
                        }
                    }
                }
            }
        }
    }
}

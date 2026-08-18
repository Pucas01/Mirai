import QtQuick
import Quickshell
import "./DivaPaint.js" as DivaPaint

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
                            Connections {
                                target: profileBtn
                                function onActiveChanged() { profileCanvas.requestPaint() }
                            }
                            onPaint: DivaPaint.paintFacetPill(profileCanvas, profileBtn.active ? 1.0 : profileCanvas.hp, 6)
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
                            onPositionChanged: mouse => {
                                profileCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                profileCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                            }
                            onClicked: batteryPopup.profileSelected(profileBtn.modelData)
                        }
                    }
                }
            }
        }
    }
}

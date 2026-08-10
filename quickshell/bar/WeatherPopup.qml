import QtQuick
import Quickshell

Window {
    id: weatherPopup
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 300
    height: 320
    visible: false

    property string glyph: ""
    property string desc: ""
    property string tempC: ""
    property string feelsLikeC: ""
    property string humidity: ""
    property string windKmph: ""
    property string uvIndex: ""
    property string areaName: ""
    property var forecast: []
    property var glyphFn: null

    function open(x, y) {
        weatherPopup.x = x
        weatherPopup.y = y
        isOpen = false
        visible = true
        weatherOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        weatherCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: weatherOpenTimer; interval: 10; onTriggered: weatherPopup.isOpen = true }
    Timer { id: weatherCloseTimer; interval: 220; onTriggered: weatherPopup.visible = false }

    function dayLabel(dateStr, index) {
        if (index === 0) return "today"
        var d = new Date(dateStr)
        return Qt.formatDateTime(d, "ddd")
    }

    component SectionBanner: Item {
        property string label: ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        height: 26

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cut = 14, w = width, h = height
                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - cut)
                ctx.lineTo(w - cut, h); ctx.lineTo(0, h); ctx.closePath()
                var base = ctx.createLinearGradient(0, 0, 0, h)
                base.addColorStop(0, "#5a5a5a"); base.addColorStop(0.08, "#454545")
                base.addColorStop(0.5, "#3a3a3a"); base.addColorStop(1.0, "#2e2e2e")
                ctx.fillStyle = base
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5); ctx.lineTo(0, h * 0.5); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                gloss.addColorStop(0, "rgba(255,255,255,0.18)")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss
                ctx.fill()
            }
        }

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
            text: parent.label.toUpperCase()
            color: "#ffffff"
            font.pixelSize: 11; font.family: "Orbitron"; font.bold: true
            font.letterSpacing: 2
        }
    }

    PanelBackground {
        id: weatherRect
        anchors.fill: parent

        opacity: weatherPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: weatherPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: weatherPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: weatherRect.width / 2; origin.y: 0; xScale: weatherRect.scaleVal; yScale: weatherRect.scaleVal },
            Translate { y: weatherRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 90

                Item {
                    id: glyphBadge
                    anchors { left: parent.left; top: parent.top; leftMargin: 12; topMargin: 10 }
                    width: 44; height: 44

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 9, w = width, h = height
                            function drawShape() {
                                ctx.beginPath()
                                ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                                ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                                ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                            }
                            drawShape()
                            var base = ctx.createLinearGradient(0, 0, 0, h)
                            base.addColorStop(0, "#80e0e0"); base.addColorStop(0.08, "#39c5bb")
                            base.addColorStop(0.5, "#2a8a8a"); base.addColorStop(1.0, "#3a6a6a")
                            ctx.fillStyle = base; ctx.fill()

                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255,0.30)")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()

                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = "#c0f4f4"; ctx.lineWidth = 1; ctx.stroke()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: weatherPopup.glyph
                        color: "#ffffff"
                        font.pixelSize: 22
                    }
                }

                Column {
                    anchors { left: parent.left; top: parent.top; leftMargin: 66; topMargin: 10 }
                    spacing: 2

                    Text {
                        text: weatherPopup.tempC + "°C"
                        color: "#ffffff"
                        font.pixelSize: 22; font.family: "monospace"; font.bold: true
                    }

                    Text {
                        text: weatherPopup.desc
                        color: "#999999"
                        font.pixelSize: 11; font.family: "monospace"
                    }

                    Text {
                        text: weatherPopup.areaName
                        color: "#555555"
                        font.pixelSize: 10; font.family: "monospace"
                        visible: weatherPopup.areaName !== ""
                    }
                }

                Text {
                    anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 12 }
                    text: "feels " + weatherPopup.feelsLikeC + "°"
                    color: "#666666"
                    font.pixelSize: 10; font.family: "monospace"
                }
            }

            SectionBanner { label: "conditions" }

            Item {
                width: parent.width
                height: 50

                Row {
                    anchors.centerIn: parent
                    spacing: 0
                    width: parent.width - 28

                    Repeater {
                        model: [
                            { label: "humidity", value: weatherPopup.humidity + "%" },
                            { label: "wind", value: weatherPopup.windKmph + " km/h" },
                            { label: "uv index", value: weatherPopup.uvIndex }
                        ]

                        delegate: Column {
                            required property var modelData
                            width: (weatherPopup.width - 28) / 3
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                color: "#39c5bb"
                                font.pixelSize: 13; font.family: "monospace"; font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: "#555555"
                                font.pixelSize: 9; font.family: "monospace"
                            }
                        }
                    }
                }
            }

            SectionBanner { label: "forecast" }

            Item { width: 1; height: 8 }

            Item {
                width: parent.width
                height: 78

                Row {
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: weatherPopup.forecast

                        delegate: Column {
                            required property var modelData
                            required property int index
                            width: (weatherPopup.width - 28) / Math.max(1, weatherPopup.forecast.length)
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weatherPopup.dayLabel(parent.modelData.date, parent.index)
                                color: "#888888"
                                font.pixelSize: 10; font.family: "monospace"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weatherPopup.glyphFn ? weatherPopup.glyphFn(parent.modelData.code) : ""
                                color: "#39c5bb"
                                font.pixelSize: 18
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.modelData.maxTempC + "°/" + parent.modelData.minTempC + "°"
                                color: "#999999"
                                font.pixelSize: 10; font.family: "monospace"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰖗 " + parent.modelData.chanceOfRain + "%"
                                color: "#555555"
                                font.pixelSize: 9; font.family: "monospace"
                            }
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Effects
import Quickshell
import "./DivaPaint.js" as DivaPaint

Window {
    id: brightnessPopup
    property bool isOpen: false
    property real brightness: 1
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 300
    height: 80
    visible: false

    signal moved(real v)

    function open(x, y) {
        brightnessPopup.x = x
        brightnessPopup.y = y
        isOpen = false
        visible = true
        brightnessOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        brightnessCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: brightnessOpenTimer; interval: 10; onTriggered: brightnessPopup.isOpen = true }
    Timer { id: brightnessCloseTimer; interval: 220; onTriggered: brightnessPopup.visible = false }

    property bool sliderActive: false
    function markSliderActive() {
        sliderActive = true
        sliderActiveResetTimer.restart()
    }
    Timer { id: sliderActiveResetTimer; interval: 300; onTriggered: brightnessPopup.sliderActive = false }

    component BrightnessSlider: Item {
        id: brSlider
        property real value: 0
        readonly property bool hovered: sliderArea.containsMouse || sliderArea.pressed
        signal moved(real v)
        height: 20

        Rectangle {
            id: sliderTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 2.5
            color: "#1c1c1c"
            border.color: "#333333"
            border.width: 1

            Rectangle {
                id: sliderFill
                width: sliderTrack.width * Math.max(0, Math.min(1, brSlider.value))
                height: parent.height
                radius: parent.radius
                color: "#f5c542"
                Behavior on width { NumberAnimation { duration: 60 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#f5c542"
                    shadowBlur: brSlider.hovered ? 0.7 : 0.4
                    shadowOpacity: brSlider.hovered ? 0.85 : 0.45
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: brSlider.hovered ? 20 : 10
                    autoPaddingEnabled: true
                }
            }

            Rectangle {
                id: sliderThumb
                x: sliderFill.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 11; height: 11; radius: 5.5
                color: "#ffffff"
                border.color: "#f5c542"
                border.width: 1.5
                scale: brSlider.hovered ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
        }

        MouseArea {
            id: sliderArea
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function updateFromX(mx) {
                brightnessPopup.markSliderActive()
                moved(Math.max(0, Math.min(1, mx / width)))
            }
            onPressed: mouse => updateFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
            onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                brightnessPopup.markSliderActive()
                moved(Math.max(0, Math.min(1, value + step)))
            }
        }
    }

    Item {
        id: brightnessRect
        anchors.fill: parent

        opacity: brightnessPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: brightnessPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: brightnessPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: brightnessRect.width / 2; origin.y: 0; xScale: brightnessRect.scaleVal; yScale: brightnessRect.scaleVal },
            Translate { y: brightnessRect.slideY }
        ]

        Item {
            id: brightnessCard
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 0; bottomMargin: 8 }

            Canvas {
                id: brightnessCardCanvas
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    var w = width, h = height, cut = 10
                    ctx.clearRect(0, 0, w, h)

                    function drawShape() {
                        ctx.beginPath()
                        ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
                        ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
                        ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
                    }

                    drawShape()
                    var base = ctx.createLinearGradient(0, 0, 0, h)
                    base.addColorStop(0, "#242424"); base.addColorStop(0.5, "#1c1c1c"); base.addColorStop(1.0, "#181818")
                    ctx.fillStyle = base; ctx.fill()

                    drawShape()
                    ctx.save()
                    ctx.clip()
                    ctx.lineWidth = 6
                    ctx.strokeStyle = "rgba(150,245,245,0.35)"
                    ctx.stroke()
                    ctx.restore()

                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                    ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                    gloss.addColorStop(0, "rgba(255,255,255,0.08)")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss; ctx.fill()

                    drawShape()
                    ctx.strokeStyle = "#c0f4f4"
                    ctx.lineWidth = 1
                    ctx.stroke()

                    drawShape()
                    ctx.strokeStyle = "rgba(150,245,245,0.9)"
                    ctx.lineWidth = 1.4
                    ctx.stroke()
                }
            }

            Item {
                id: brightnessIconBadge
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                width: 26; height: 26

                Canvas {
                    id: brightnessIconCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: DivaPaint.paintFacetPill(brightnessIconCanvas, 0.0, 5, DivaPaint.ACCENT_AMBER)
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰃟"
                    color: "#f5c542"
                    font.pixelSize: 15
                }
            }

            BrightnessSlider {
                anchors { left: brightnessIconBadge.right; right: pctText.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                value: brightnessPopup.brightness
                onMoved: v => brightnessPopup.moved(v)
            }

            Text {
                id: pctText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(brightnessPopup.brightness * 100) + "%"
                color: "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
        }
    }
}

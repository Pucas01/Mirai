import QtQuick
import Quickshell

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
        property real value: 0
        signal moved(real v)
        height: 20

        Rectangle {
            id: sliderTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 2.5
            color: "#2a2a2a"

            Rectangle {
                width: sliderTrack.width * Math.max(0, Math.min(1, parent.parent.value))
                height: parent.height
                radius: parent.radius
                color: "#f5c542"
                Behavior on width { NumberAnimation { duration: 60 } }
            }
        }

        MouseArea {
            anchors { fill: parent; margins: -4 }
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

    PanelBackground {
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
            anchors { fill: parent; margins: 1 }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                text: "󰃟"
                color: "#f5c542"
                font.pixelSize: 15
            }

            BrightnessSlider {
                anchors { left: parent.left; right: pctText.left; verticalCenter: parent.verticalCenter; leftMargin: 50; rightMargin: 10 }
                value: brightnessPopup.brightness
                onMoved: v => brightnessPopup.moved(v)
            }

            Text {
                id: pctText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(brightnessPopup.brightness * 100) + "%"
                color: "#999999"
                font.pixelSize: 10; font.family: "monospace"
            }
        }
    }
}

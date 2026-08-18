import QtQuick
import "./DivaPaint.js" as DivaPaint

Item {
    id: root
    default property alias content: contentItem.children

    property string shape: "pill"
    property int cut: 5
    property int slant: 24
    property var accent: DivaPaint.ACCENT_TEAL

    property bool active: false
    property real activeProgress: active ? 1.0 : 0.0
    property real pulse: 0.0

    readonly property bool hovered: mouseArea.containsMouse
    property alias cursorShape: mouseArea.cursorShape
    property alias acceptedButtons: mouseArea.acceptedButtons

    signal clicked(var mouse)
    signal wheel(var wheel)

    Behavior on activeProgress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Canvas {
        id: canvas
        anchors.fill: parent
        property real hoverProgress: 0.0
        property real mx: 0.5
        property real my: 0.5
        Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on mx { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on my { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        onHoverProgressChanged: requestPaint()
        onMxChanged: requestPaint()
        onMyChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onActiveProgressChanged() { canvas.requestPaint() }
            function onPulseChanged() { canvas.requestPaint() }
        }
        onPaint: {
            if (root.shape === "slant") {
                DivaPaint.paintFacetSlant(canvas, Math.max(hoverProgress, root.activeProgress), root.slant, root.accent)
            } else if (root.shape === "ws") {
                DivaPaint.paintWsPill(canvas, root.activeProgress, hoverProgress, root.pulse)
            } else {
                DivaPaint.paintFacetPill(canvas, Math.max(hoverProgress, root.activeProgress), root.cut, root.accent)
            }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: canvas.hoverProgress = containsMouse ? 1.0 : 0.0
        onPositionChanged: mouse => {
            canvas.mx = Math.max(0, Math.min(1, mouse.x / width))
            canvas.my = Math.max(0, Math.min(1, mouse.y / height))
        }
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheel(wheel)
    }
}

import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: folderBtn
    signal clicked()
    width: 28; height: 22

    Canvas {
        id: folderBtnCanvas
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
        onPaint: DivaPaint.paintFacetPill(folderBtnCanvas, folderBtnCanvas.hp, 4)
    }

    Text {
        anchors.centerIn: parent
        text: "󰝰"
        color: folderBtnArea.containsMouse ? "#ffffff" : "#999999"
        font.pixelSize: 12
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: folderBtnArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: folderBtnCanvas.hp = containsMouse ? 1.0 : 0.0
        onPositionChanged: mouse => {
            folderBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
            folderBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
        }
        onClicked: folderBtn.clicked()
    }
}

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
        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        onHpChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, folderBtnCanvas.hp, 4)
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
        onClicked: folderBtn.clicked()
    }
}

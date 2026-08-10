import QtQuick

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
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cut = 4, w = width, h = height, hp = folderBtnCanvas.hp
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
            if (hp > 0) {
                drawShape()
                var teal = ctx.createLinearGradient(0, 0, 0, h)
                teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                ctx.globalAlpha = hp; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
            }
            ctx.beginPath()
            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
            gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
            ctx.fillStyle = gloss; ctx.fill()
            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
            ctx.strokeStyle = hp > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
        }
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

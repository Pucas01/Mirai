import QtQuick

Item {
    id: popupCard
    default property alias content: cardContent.children
    property int cut: 12

    Canvas {
        id: cardCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height, cut = popupCard.cut
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
        id: cardContent
        anchors { fill: parent; margins: 1 }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io

Window {
    id: editorWin
    property string imagePath: ""
    property int trigger: 0
    property string tool: "arrow"
    property string drawColor: "#ff5555"
    property real strokeWidth: 4
    property var strokes: []
    property var undone: []
    property var activeStroke: null
    property var pendingText: null

    readonly property var toolColors: ["#ff5555", "#ffd93d", "#39c5bb", "#4ade80", "#ffffff", "#1a1a1a"]

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    visible: false
    title: "qs-screenshot-editor"

    Timer { id: keyFocusTimer; interval: 30; onTriggered: keyCatcher.forceActiveFocus() }

    function open(path, trig) {
        editorWin.imagePath = path
        editorWin.trigger = trig
        editorWin.strokes = []
        editorWin.undone = []
        editorWin.activeStroke = null
        baseImage.source = ""
        baseImage.source = "file://" + path + "?t=" + trig
    }

    function closeEditor() {
        editorWin.visible = false
    }

    onVisibleChanged: {
        if (visible) keyFocusTimer.start()
        else commitPendingText()
    }

    Connections {
        target: baseImage
        function onStatusChanged() {
            if (baseImage.status !== Image.Ready) return
            var w = baseImage.sourceSize.width
            var h = baseImage.sourceSize.height
            canvas.width = w
            canvas.height = h
            editorWin.width = Math.max(480, w) + 24
            editorWin.height = Math.max(360, h) + titleBar.height + toolbar.height + 56
            canvas.requestPaint()
        }
    }

    function pushStroke(stroke) {
        var s = editorWin.strokes.slice()
        s.push(stroke)
        editorWin.strokes = s
        editorWin.undone = []
        canvas.requestPaint()
    }

    function undo() {
        commitPendingText()
        if (editorWin.strokes.length === 0) return
        var s = editorWin.strokes.slice()
        var removed = s.pop()
        editorWin.strokes = s
        var u = editorWin.undone.slice()
        u.push(removed)
        editorWin.undone = u
        canvas.requestPaint()
    }

    function redo() {
        if (editorWin.undone.length === 0) return
        var u = editorWin.undone.slice()
        var restored = u.pop()
        editorWin.undone = u
        var s = editorWin.strokes.slice()
        s.push(restored)
        editorWin.strokes = s
        canvas.requestPaint()
    }

    function commitPendingText() {
        if (!editorWin.pendingText) return
        var txt = textInput.text
        if (txt.length > 0) {
            pushStroke({
                type: "text",
                x: editorWin.pendingText.x,
                y: editorWin.pendingText.y,
                text: txt,
                color: editorWin.drawColor,
                size: 8 + editorWin.strokeWidth * 3
            })
        }
        editorWin.pendingText = null
        textInput.text = ""
    }

    property string pendingBase64: ""

    Process {
        id: copyToClipboardProc
        command: ["bash", "-c", "base64 -d | wl-copy"]
        stdinEnabled: true
        onStarted: {
            write(editorWin.pendingBase64)
            stdinEnabled = false
        }
        onExited: code => {
            if (code === 0) editorWin.closeEditor()
        }
    }

    function copyToClipboard(dataUrl) {
        var idx = dataUrl.indexOf("base64,")
        if (idx === -1) return
        editorWin.pendingBase64 = dataUrl.substring(idx + 7)
        copyToClipboardProc.running = false
        copyToClipboardProc.running = true
    }

    function arrowHeadLength(sw) {
        return 10 + sw * 3.5
    }

    function drawArrowHead(ctx, x1, y1, x2, y2, sw) {
        var angle = Math.atan2(y2 - y1, x2 - x1)
        var headLen = arrowHeadLength(sw)
        ctx.beginPath()
        ctx.moveTo(x2, y2)
        ctx.lineTo(x2 - headLen * Math.cos(angle - Math.PI / 7), y2 - headLen * Math.sin(angle - Math.PI / 7))
        ctx.lineTo(x2 - headLen * Math.cos(angle + Math.PI / 7), y2 - headLen * Math.sin(angle + Math.PI / 7))
        ctx.closePath()
        ctx.fill()
    }

    function drawStroke(ctx, st) {
        ctx.strokeStyle = st.color
        ctx.fillStyle = st.color
        ctx.lineWidth = st.width
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (st.type === "freehand") {
            if (st.points.length < 2) return
            ctx.beginPath()
            ctx.moveTo(st.points[0].x, st.points[0].y)
            for (var i = 1; i < st.points.length; i++) ctx.lineTo(st.points[i].x, st.points[i].y)
            ctx.stroke()
        } else if (st.type === "arrow") {
            var dx = st.x2 - st.x1, dy = st.y2 - st.y1
            var len = Math.hypot(dx, dy)
            var headLen = editorWin.arrowHeadLength(st.width)
            var shaftFrac = len > headLen ? (len - headLen * 0.6) / len : 1
            ctx.beginPath()
            ctx.moveTo(st.x1, st.y1)
            ctx.lineTo(st.x1 + dx * shaftFrac, st.y1 + dy * shaftFrac)
            ctx.stroke()
            drawArrowHead(ctx, st.x1, st.y1, st.x2, st.y2, st.width)
        } else if (st.type === "rect") {
            ctx.strokeRect(Math.min(st.x1, st.x2), Math.min(st.y1, st.y2), Math.abs(st.x2 - st.x1), Math.abs(st.y2 - st.y1))
        } else if (st.type === "ellipse") {
            var cx = (st.x1 + st.x2) / 2, cy = (st.y1 + st.y2) / 2
            var rx = Math.abs(st.x2 - st.x1) / 2, ry = Math.abs(st.y2 - st.y1) / 2
            ctx.beginPath()
            ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
            ctx.stroke()
        } else if (st.type === "text") {
            ctx.font = st.size + "px sans-serif"
            ctx.textBaseline = "top"
            ctx.fillText(st.text, st.x, st.y)
        }
    }

    component EditorBtn: Item {
        property string label: ""
        property bool active: false
        property int btnWidth: 34
        signal clicked()
        width: btnWidth; height: 34

        Canvas {
            id: btnCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cut = 5, w = width, h = height, ta = parent.active ? 1.0 : Math.max(hp, 0)
                function drawShape() {
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - cut)
                    ctx.lineTo(w - cut, h); ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
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
                ctx.beginPath(); ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + ta * 0.2) + ")")
                gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss; ctx.fill()
                ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
            }
        }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: btnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
            font.pixelSize: 13; font.family: "monospace"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: btnCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: parent.clicked()
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) {
                    editorWin.redo(); event.accepted = true
                } else if (event.key === Qt.Key_Z) {
                    editorWin.undo(); event.accepted = true
                } else if (event.key === Qt.Key_Y) {
                    editorWin.redo(); event.accepted = true
                }
            } else if (event.key === Qt.Key_Escape) {
                editorWin.closeEditor(); event.accepted = true
            }
        }

        PanelBackground {
            anchors.fill: parent

            Item {
                id: titleBar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 38

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: "screenshot editor"
                    color: "#39c5bb"
                    font.pixelSize: 11; font.family: "Orbitron"
                }

                Item {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    width: 28; height: 22

                    Canvas {
                        id: closeBtnCanvas
                        anchors.fill: parent
                        property real hp: 0.0
                        Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onHpChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cut = 4, w = width, h = height, hp = closeBtnCanvas.hp
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
                                var red = ctx.createLinearGradient(0, 0, 0, h)
                                red.addColorStop(0, "#f08080"); red.addColorStop(0.08, "#cc4444")
                                red.addColorStop(0.5, "#992e2e"); red.addColorStop(1.0, "#6a2a2a")
                                ctx.globalAlpha = hp; ctx.fillStyle = red; ctx.fill(); ctx.globalAlpha = 1.0
                            }
                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                            ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()
                            ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                            ctx.strokeStyle = hp > 0.5 ? "#ffc0c0" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: closeBtnCanvas.hp = containsMouse ? 1.0 : 0.0
                        onClicked: editorWin.closeEditor()
                    }
                }

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: "#2a2a2a"
                }

                DragHandler {
                    target: null
                    onActiveChanged: if (active) editorWin.startSystemMove()
                }
            }

            Column {
                anchors { top: titleBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                spacing: 8

                Item {
                    id: toolbar
                    width: parent.width
                    height: 34

                    component ToolBtn: EditorBtn {
                        property string toolName: ""
                        active: editorWin.tool === toolName
                        onClicked: { editorWin.commitPendingText(); editorWin.tool = toolName }
                    }

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        ToolBtn { toolName: "arrow"; label: "↗" }
                        ToolBtn { toolName: "rect"; label: "□" }
                        ToolBtn { toolName: "ellipse"; label: "◯" }
                        ToolBtn { toolName: "freehand"; label: "✏" }
                        ToolBtn { toolName: "text"; label: "T" }

                        Item { width: 12; height: 1 }

                        Repeater {
                            model: editorWin.toolColors
                            delegate: Rectangle {
                                required property string modelData
                                width: 22; height: 22; radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData
                                border.width: editorWin.drawColor === modelData ? 2 : 1
                                border.color: editorWin.drawColor === modelData ? "#ffffff" : "#555555"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editorWin.drawColor = parent.color.toString()
                                }
                            }
                        }

                        Item { width: 12; height: 1 }

                        Rectangle {
                            id: widthTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90; height: 34
                            color: "#242424"
                            border.color: "#2e2e2e"; border.width: 1

                            Rectangle {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; margins: 2 }
                                width: (parent.width - 4) * ((editorWin.strokeWidth - 1) / 13)
                                height: parent.height - 4
                                color: "#39c5bb"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(editorWin.strokeWidth) + "px"
                                color: "#e0e0e0"
                                font.pixelSize: 10; font.family: "monospace"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function setFromX(mx) {
                                    var frac = Math.max(0, Math.min(1, mx / width))
                                    editorWin.strokeWidth = 1 + frac * 13
                                }
                                onPressed: mouse => setFromX(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                            }
                        }

                        Item { width: 12; height: 1 }

                        EditorBtn { label: "↶"; onClicked: editorWin.undo() }
                        EditorBtn { label: "↷"; onClicked: editorWin.redo() }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        EditorBtn {
                            label: "cancel"
                            btnWidth: 70
                            onClicked: editorWin.closeEditor()
                        }
                        EditorBtn {
                            label: "copy"
                            btnWidth: 70
                            active: true
                            onClicked: {
                                editorWin.commitPendingText()
                                var ctx = canvas.getContext("2d")
                                ctx.clearRect(0, 0, canvas.width, canvas.height)
                                if (baseImage.status === Image.Ready) ctx.drawImage(baseImage, 0, 0, canvas.width, canvas.height)
                                for (var i = 0; i < editorWin.strokes.length; i++) editorWin.drawStroke(ctx, editorWin.strokes[i])
                                editorWin.copyToClipboard(canvas.toDataURL("image/png"))
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - toolbar.height - parent.spacing
                    color: "#0d0d0d"
                    border.color: "#242424"; border.width: 1
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        contentWidth: canvas.width
                        contentHeight: canvas.height
                        clip: true
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            width: canvas.width
                            height: canvas.height

                            Image {
                                id: baseImage
                                visible: false
                            }

                            Canvas {
                                id: canvas
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    if (baseImage.status === Image.Ready) ctx.drawImage(baseImage, 0, 0, width, height)
                                    for (var i = 0; i < editorWin.strokes.length; i++) editorWin.drawStroke(ctx, editorWin.strokes[i])
                                    if (editorWin.activeStroke) editorWin.drawStroke(ctx, editorWin.activeStroke)
                                }
                            }

                            TextInput {
                                id: textInput
                                visible: editorWin.pendingText !== null
                                x: editorWin.pendingText ? editorWin.pendingText.x : 0
                                y: editorWin.pendingText ? editorWin.pendingText.y : 0
                                font.pixelSize: 8 + editorWin.strokeWidth * 3
                                color: editorWin.drawColor
                                focus: visible
                                onAccepted: { editorWin.commitPendingText(); canvas.requestPaint(); keyCatcher.forceActiveFocus() }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.CrossCursor
                                onPressed: mouse => {
                                    editorWin.commitPendingText()
                                    if (editorWin.tool === "text") {
                                        editorWin.pendingText = { x: mouse.x, y: mouse.y }
                                        textInput.forceActiveFocus()
                                        return
                                    }
                                    keyCatcher.forceActiveFocus()
                                    if (editorWin.tool === "freehand") {
                                        editorWin.activeStroke = { type: "freehand", color: editorWin.drawColor, width: editorWin.strokeWidth, points: [{x: mouse.x, y: mouse.y}] }
                                    } else {
                                        editorWin.activeStroke = { type: editorWin.tool, color: editorWin.drawColor, width: editorWin.strokeWidth, x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y }
                                    }
                                    canvas.requestPaint()
                                }
                                onPositionChanged: mouse => {
                                    if (!editorWin.activeStroke) return
                                    if (editorWin.tool === "freehand") {
                                        editorWin.activeStroke.points.push({x: mouse.x, y: mouse.y})
                                    } else {
                                        editorWin.activeStroke.x2 = mouse.x
                                        editorWin.activeStroke.y2 = mouse.y
                                    }
                                    canvas.requestPaint()
                                }
                                onReleased: {
                                    if (!editorWin.activeStroke) return
                                    var st = editorWin.activeStroke
                                    editorWin.activeStroke = null
                                    editorWin.pushStroke(st)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

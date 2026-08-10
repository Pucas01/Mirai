import QtQuick
import ".."

Item {
    id: monitorsSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: monitorsSection.slideY }

    component MonBtn: Item {
        property string label: ""
        property bool active: false
        signal clicked()
        width: 72; height: 24
        onActiveChanged: monBtnCanvas.requestPaint()

        Canvas {
            id: monBtnCanvas
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
                    ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h-cut)
                    ctx.lineTo(w-cut,h); ctx.lineTo(0,h); ctx.lineTo(0,cut); ctx.closePath()
                }
                drawShape()
                var base = ctx.createLinearGradient(0,0,0,h)
                base.addColorStop(0,"#3d3d3d"); base.addColorStop(0.08,"#2a2a2a")
                base.addColorStop(0.5,"#303030"); base.addColorStop(1.0,"#3a3a3a")
                ctx.fillStyle = base; ctx.fill()
                if (ta > 0) {
                    drawShape()
                    var teal = ctx.createLinearGradient(0,0,0,h)
                    teal.addColorStop(0,"#80e0e0"); teal.addColorStop(0.08,"#39c5bb")
                    teal.addColorStop(0.5,"#2a8a8a"); teal.addColorStop(1.0,"#3a6a6a")
                    ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                }
                ctx.beginPath(); ctx.moveTo(cut,0); ctx.lineTo(w,0); ctx.lineTo(w,h*0.62)
                ctx.lineTo(0,h*0.62); ctx.lineTo(0,cut); ctx.closePath()
                var gloss = ctx.createLinearGradient(0,0,0,h*0.62)
                gloss.addColorStop(0,"rgba(255,255,255,"+(0.12+ta*0.2)+")")
                gloss.addColorStop(1,"rgba(255,255,255,0.00)")
                ctx.fillStyle = gloss; ctx.fill()
                ctx.beginPath(); ctx.moveTo(cut,0.5); ctx.lineTo(w,0.5)
                ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
            }
        }
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: monBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
            font.pixelSize: 10; font.family: "monospace"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        MouseArea {
            id: monBtnArea
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: monBtnCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: parent.clicked()
        }
    }

    Item {
        id: monHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44
        z: 5

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: modeDropdown.left; rightMargin: 12 }
            label: "monitors"
        }

        Row {
            id: monActionRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            spacing: 6

            MonBtn {
                label: "refresh"
                active: settingsWin.monitorsRefreshed
                onClicked: settingsWin.refreshMonitors()
            }
            MonBtn {
                label: "apply"
                active: settingsWin.monitorsApplied
                onClicked: settingsWin.applyMonitors()
            }
            MonBtn {
                label: "save"
                active: settingsWin.monitorsSaved
                onClicked: settingsWin.saveMonitors()
            }
        }

        Item {
            id: modeDropdown
            anchors { right: monActionRow.left; verticalCenter: parent.verticalCenter; rightMargin: 12 }
            width: 168; height: 24

            Canvas {
                id: modeDropdownCanvas
                anchors.fill: parent
                property real hp: 0.0
                Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                onHpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cut = 5, w = width, h = height, ta = modeDropdown.open ? 1.0 : Math.max(hp, 0)
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
                    if (ta > 0) {
                        drawShape()
                        var teal = ctx.createLinearGradient(0, 0, 0, h)
                        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
                        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
                        ctx.globalAlpha = ta; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
                    }
                    ctx.beginPath()
                    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
                    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
                    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
                    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + ta * 0.2) + ")")
                    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                    ctx.fillStyle = gloss; ctx.fill()
                    ctx.beginPath(); ctx.moveTo(cut, 0.5); ctx.lineTo(w, 0.5)
                    ctx.strokeStyle = ta > 0.5 ? "#c0f4f4" : "#646464"; ctx.lineWidth = 1; ctx.stroke()
                }
            }

            property bool open: false
            onOpenChanged: modeDropdownCanvas.requestPaint()

            Text {
                anchors { left: parent.left; right: modeArrow.left; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 4 }
                text: settingsWin.selectedMonitor
                    ? (settingsWin.selectedMonitor.width + "x" + settingsWin.selectedMonitor.height + "@" + settingsWin.selectedMonitor.refreshRate.toFixed(2))
                    : "select a monitor"
                color: settingsWin.selectedMonitor ? "#dddddd" : "#666666"
                font.pixelSize: 10; font.family: "monospace"
                elide: Text.ElideRight
            }

            Text {
                id: modeArrow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                text: modeDropdown.open ? "▲" : "▼"
                color: "#888888"
                font.pixelSize: 8
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: settingsWin.selectedMonitor ? Qt.PointingHandCursor : Qt.ArrowCursor
                onContainsMouseChanged: modeDropdownCanvas.hp = containsMouse ? 1.0 : 0.0
                onClicked: {
                    if (settingsWin.selectedMonitor) modeDropdown.open = !modeDropdown.open
                }
            }

            PanelBackground {
                id: modeListBg
                visible: modeDropdown.open && settingsWin.selectedMonitor !== null
                anchors { top: parent.bottom; left: parent.left; topMargin: 4 }
                width: 190
                height: Math.min(200, modeListView.contentHeight + 8)
                z: 100

                ListView {
                    id: modeListView
                    anchors { fill: parent; margins: 4 }
                    clip: true
                    model: settingsWin.selectedMonitor ? settingsWin.selectedMonitor.availableModes : []

                    delegate: Item {
                        id: modeItem
                        required property string modelData
                        width: modeListView.width
                        height: 22

                        Rectangle {
                            anchors.fill: parent
                            color: modeItemArea.containsMouse ? "#242424" : "transparent"
                        }

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 6 }
                            text: modeItem.modelData.replace("Hz", "")
                            color: modeItemArea.containsMouse ? "#ffffff" : "#cccccc"
                            font.pixelSize: 10; font.family: "monospace"
                        }

                        MouseArea {
                            id: modeItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var m = modeItem.modelData.match(/(\d+)x(\d+)@([\d.]+)/)
                                if (m && settingsWin.selectedMonitor) {
                                    settingsWin.setMonitorMode(settingsWin.selectedMonitor.name, parseInt(m[1]), parseInt(m[2]), parseFloat(m[3]))
                                }
                                modeDropdown.open = false
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: monitorsCanvas
        anchors { top: monHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 14 }

        readonly property real padding: 24
        readonly property real minX: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.min(a, m.x), Infinity) : 0
        readonly property real minY: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.min(a, m.y), Infinity) : 0
        readonly property real maxX: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.max(a, m.x + m.width), -Infinity) : 1
        readonly property real maxY: settingsWin.monitors.length ? settingsWin.monitors.reduce((a, m) => Math.max(a, m.y + m.height), -Infinity) : 1
        readonly property real totalW: Math.max(1, maxX - minX)
        readonly property real totalH: Math.max(1, maxY - minY)
        readonly property real scaleFactor: settingsWin.monitors.length
            ? Math.min((width - padding * 2) / totalW, (height - padding * 2) / totalH)
            : 1

        readonly property real snapPx: 10

        function toPixelX(modelX) { return monitorsCanvas.padding + (modelX - monitorsCanvas.minX) * monitorsCanvas.scaleFactor }
        function toPixelY(modelY) { return monitorsCanvas.padding + (modelY - monitorsCanvas.minY) * monitorsCanvas.scaleFactor }
        function toModelX(pixelX) { return monitorsCanvas.minX + (pixelX - monitorsCanvas.padding) / monitorsCanvas.scaleFactor }
        function toModelY(pixelY) { return monitorsCanvas.minY + (pixelY - monitorsCanvas.padding) / monitorsCanvas.scaleFactor }

        function cloneMonitors() {
            return settingsWin.monitors.map(function(m) {
                var c = {}
                for (var k in m) c[k] = m[k]
                return c
            })
        }

        function snapPos(mon, rawX, rawY, others) {
            var thresholdModel = monitorsCanvas.snapPx / monitorsCanvas.scaleFactor
            var bestX = rawX, bestXDist = thresholdModel
            var bestY = rawY, bestYDist = thresholdModel
            for (var i = 0; i < others.length; i++) {
                var o = others[i]
                if (o === mon) continue
                var xCandidates = [o.x - mon.width, o.x, o.x + o.width - mon.width, o.x + o.width, o.x + o.width / 2 - mon.width / 2]
                for (var xi = 0; xi < xCandidates.length; xi++) {
                    var dx = Math.abs(rawX - xCandidates[xi])
                    if (dx < bestXDist) { bestXDist = dx; bestX = xCandidates[xi] }
                }
                var yCandidates = [o.y - mon.height, o.y, o.y + o.height - mon.height, o.y + o.height, o.y + o.height / 2 - mon.height / 2]
                for (var yi = 0; yi < yCandidates.length; yi++) {
                    var dy = Math.abs(rawY - yCandidates[yi])
                    if (dy < bestYDist) { bestYDist = dy; bestY = yCandidates[yi] }
                }
            }
            return { x: bestX, y: bestY }
        }

        function liveSnapPixels(box, px, py) {
            var bestX = px, bestXDist = monitorsCanvas.snapPx
            var bestY = py, bestYDist = monitorsCanvas.snapPx
            for (var i = 0; i < monRepeater.count; i++) {
                var other = monRepeater.itemAt(i)
                if (!other || other === box) continue
                var ox = other.x, oy = other.y, ow = other.width, oh = other.height
                var xCandidates = [ox - box.width, ox, ox + ow - box.width, ox + ow, ox + ow / 2 - box.width / 2]
                for (var xi = 0; xi < xCandidates.length; xi++) {
                    var dx = Math.abs(px - xCandidates[xi])
                    if (dx < bestXDist) { bestXDist = dx; bestX = xCandidates[xi] }
                }
                var yCandidates = [oy - box.height, oy, oy + oh - box.height, oy + oh, oy + oh / 2 - box.height / 2]
                for (var yi = 0; yi < yCandidates.length; yi++) {
                    var dy = Math.abs(py - yCandidates[yi])
                    if (dy < bestYDist) { bestYDist = dy; bestY = yCandidates[yi] }
                }
            }
            return { x: bestX, y: bestY }
        }

        function moveMonitor(index, rawModelX, rawModelY) {
            var arr = monitorsCanvas.cloneMonitors()
            var mon = arr[index]
            var snapped = monitorsCanvas.snapPos(mon, rawModelX, rawModelY, arr)
            var boxW = Math.max(50, mon.width * monitorsCanvas.scaleFactor)
            var boxH = Math.max(36, mon.height * monitorsCanvas.scaleFactor)
            var px = Math.max(0, Math.min(monitorsCanvas.width - boxW, monitorsCanvas.toPixelX(snapped.x)))
            var py = Math.max(0, Math.min(monitorsCanvas.height - boxH, monitorsCanvas.toPixelY(snapped.y)))
            mon.x = Math.round(monitorsCanvas.toModelX(px))
            mon.y = Math.round(monitorsCanvas.toModelY(py))
            settingsWin.monitors = arr
        }

        function scaleMonitor(index, delta) {
            var arr = monitorsCanvas.cloneMonitors()
            arr[index].scale = Math.max(0.5, Math.min(3.0, arr[index].scale + delta))
            settingsWin.monitors = arr
        }

        Rectangle {
            anchors.fill: parent
            color: "#111111"
            border.color: "#2a2a2a"
            border.width: 1
        }

        Repeater {
            id: monRepeater
            model: settingsWin.monitors

            delegate: Item {
                id: monBox
                required property var modelData
                required property int index
                readonly property bool selected: settingsWin.selectedMonitorName === modelData.name
                x: monitorsCanvas.toPixelX(modelData.x)
                y: monitorsCanvas.toPixelY(modelData.y)
                width: Math.max(50, modelData.width * monitorsCanvas.scaleFactor)
                height: Math.max(36, modelData.height * monitorsCanvas.scaleFactor)
                z: monDragHandler.active ? 10 : (modelData.focused ? 2 : 1)

                Rectangle {
                    anchors.fill: parent
                    color: monDragHandler.active ? "#2a4a48" : (monHoverHandler.hovered ? "#243030" : "#1e2424")
                    border.color: monDragHandler.active || monHoverHandler.hovered || monBox.selected ? "#39c5bb" : "#3a3a3a"
                    border.width: monDragHandler.active || monBox.selected ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monBox.modelData.name
                            color: "#e0e0e0"
                            font.pixelSize: 11; font.family: "monospace"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monBox.modelData.width + "x" + monBox.modelData.height + " @" + monBox.modelData.scale.toFixed(2) + "x"
                            color: "#777777"
                            font.pixelSize: 9; font.family: "monospace"
                        }
                    }
                }

                HoverHandler {
                    id: monHoverHandler
                    cursorShape: Qt.SizeAllCursor
                }

                TapHandler {
                    onTapped: settingsWin.selectedMonitorName = monBox.modelData.name
                }

                WheelHandler {
                    onWheel: event => {
                        var d = event.angleDelta.y > 0 ? 0.05 : -0.05
                        monitorsCanvas.scaleMonitor(monBox.index, d)
                    }
                }

                DragHandler {
                    id: monDragHandler
                    target: null
                    property real dragStartPixelX: 0
                    property real dragStartPixelY: 0
                    onActiveChanged: {
                        if (active) {
                            dragStartPixelX = monBox.x
                            dragStartPixelY = monBox.y
                        } else {
                            var rawX = monitorsCanvas.toModelX(monBox.x)
                            var rawY = monitorsCanvas.toModelY(monBox.y)
                            monitorsCanvas.moveMonitor(monBox.index, rawX, rawY)
                        }
                    }
                    onTranslationChanged: {
                        if (!active) return
                        var px = Math.max(0, Math.min(monitorsCanvas.width - monBox.width, dragStartPixelX + translation.x))
                        var py = Math.max(0, Math.min(monitorsCanvas.height - monBox.height, dragStartPixelY + translation.y))
                        var snapped = monitorsCanvas.liveSnapPixels(monBox, px, py)
                        monBox.x = snapped.x
                        monBox.y = snapped.y
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: settingsWin.monitors.length === 0 && settingsWin.monitorsError === ""
            text: "loading monitors..."
            color: "#444444"
            font.pixelSize: 11; font.family: "monospace"
        }

        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            visible: settingsWin.monitorsError !== ""
            text: settingsWin.monitorsError
            color: "#ff6b6b"
            font.pixelSize: 10; font.family: "monospace"
            elide: Text.ElideRight
        }
    }
}

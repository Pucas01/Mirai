import QtQuick
import Quickshell
import Quickshell.Io
import "./DivaPaint.js" as DivaPaint

Window {
    id: calendarPopup
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 512
    visible: false

    property var todos: []
    readonly property string todosPath: Quickshell.env("HOME") + "/.cache/qs-todos.json"

    property date viewDate: new Date()
    property date today: new Date()

    function open(x, y) {
        calendarPopup.x = x
        calendarPopup.y = y
        calendarPopup.viewDate = new Date()
        isOpen = false
        visible = true
        calendarOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        calendarCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: calendarOpenTimer; interval: 10; onTriggered: calendarPopup.isOpen = true }
    Timer { id: calendarCloseTimer; interval: 220; onTriggered: calendarPopup.visible = false }

    Component.onCompleted: loadTodosProc.running = true

    Process {
        id: loadTodosProc
        command: ["cat", calendarPopup.todosPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try { calendarPopup.todos = JSON.parse(text) } catch (_) { calendarPopup.todos = [] }
            }
        }
    }

    Process {
        id: saveTodosProc
        command: ["true"]
        running: false
    }

    function persistTodos() {
        saveTodosProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + calendarPopup.todosPath + "\" <<'TODOS_EOF'\n" + JSON.stringify(calendarPopup.todos) + "\nTODOS_EOF\n"]
        saveTodosProc.running = false
        saveTodosProc.running = true
    }

    function addTodo(text) {
        var t = text.trim()
        if (t === "") return
        var list = todos.slice()
        list.push({ text: t, done: false, created: Date.now() })
        todos = list
        persistTodos()
    }

    function toggleTodo(index) {
        var list = todos.slice()
        list[index] = { text: list[index].text, done: !list[index].done, created: list[index].created }
        todos = list
        persistTodos()
    }

    function removeTodo(index) {
        var list = todos.slice()
        list.splice(index, 1)
        todos = list
        persistTodos()
    }

    function shiftMonth(delta) {
        var d = new Date(viewDate)
        d.setDate(1)
        d.setMonth(d.getMonth() + delta)
        viewDate = d
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstWeekdayOfMonth(year, month) {
        return new Date(year, month, 1).getDay()
    }

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
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

    PopupCard {
        id: calendarRect
        anchors.fill: parent

        opacity: calendarPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: calendarPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: calendarPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: calendarRect.width / 2; origin.y: 0; xScale: calendarRect.scaleVal; yScale: calendarRect.scaleVal },
            Translate { y: calendarRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item { width: 1; height: 12 }

            Item {
                width: parent.width
                height: 22

                Text {
                    id: monthLabel
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(calendarPopup.viewDate, "MMMM yyyy")
                    color: "#f0f0f0"
                    font.pixelSize: 14; font.family: "monospace"; font.bold: true
                    font.letterSpacing: 0.5
                }

                GlowButton {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    width: 22; height: 22
                    cut: 5
                    onClicked: calendarPopup.shiftMonth(-1)

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1
                        text: "‹"
                        color: parent.hovered ? "#101010" : "#999999"
                        font.pixelSize: 15; font.bold: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                GlowButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    width: 22; height: 22
                    cut: 5
                    onClicked: calendarPopup.shiftMonth(1)

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        text: "›"
                        color: parent.hovered ? "#101010" : "#999999"
                        font.pixelSize: 15; font.bold: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            Item { width: 1; height: 14 }

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.centerIn: parent
                    width: parent.width - 28

                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        delegate: Text {
                            required property string modelData
                            width: (calendarRect.width - 28) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: "#4a4a4a"
                            font.pixelSize: 9; font.family: "monospace"; font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

            Item {
                width: parent.width
                height: 186

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 28
                    spacing: 0

                    property var weeks: {
                        var year = calendarPopup.viewDate.getFullYear()
                        var month = calendarPopup.viewDate.getMonth()
                        var lead = calendarPopup.firstWeekdayOfMonth(year, month)
                        var total = calendarPopup.daysInMonth(year, month)
                        var cells = []
                        for (var i = 0; i < lead; i++) cells.push(0)
                        for (var d = 1; d <= total; d++) cells.push(d)
                        while (cells.length % 7 !== 0) cells.push(0)
                        var rows = []
                        for (var r = 0; r < cells.length; r += 7) rows.push(cells.slice(r, r + 7))
                        return rows
                    }

                    Repeater {
                        model: parent.weeks

                        delegate: Row {
                            id: weekRow
                            required property var modelData
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: weekRow.modelData

                                delegate: Item {
                                    id: dayCell
                                    required property int modelData
                                    width: (calendarRect.width - 28) / 7
                                    height: 31

                                    readonly property bool isToday: modelData > 0 && calendarPopup.isSameDay(
                                        new Date(calendarPopup.viewDate.getFullYear(), calendarPopup.viewDate.getMonth(), modelData),
                                        calendarPopup.today)

                                    GlowButton {
                                        id: dayGlow
                                        anchors.centerIn: parent
                                        width: 26; height: 26
                                        cut: 5
                                        visible: dayCell.modelData > 0
                                        active: dayCell.isToday
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.ArrowCursor

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.modelData > 0 ? dayCell.modelData : ""
                                            color: dayCell.isToday ? "#0c1414" : (dayGlow.hovered ? "#f0f0f0" : "#a0a0a0")
                                            font.pixelSize: 11; font.family: "monospace"; font.bold: dayCell.isToday
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 16 }

            SectionBanner { label: "todo" }

            Item { width: 1; height: 12 }

            Item {
                width: parent.width
                height: 34

                Item {
                    id: todoInputBox
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 2; bottomMargin: 2 }

                    Canvas {
                        id: todoInputCanvas
                        anchors.fill: parent
                        property real focusProgress: todoInput.activeFocus ? 1.0 : 0.0
                        Behavior on focusProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        onFocusProgressChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height, fp = focusProgress, cut = 8
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

                            if (fp > 0) {
                                drawShape()
                                ctx.save()
                                ctx.clip()
                                ctx.lineWidth = 6
                                ctx.strokeStyle = "rgba(150,245,245," + (fp * 0.35) + ")"
                                ctx.stroke()
                                ctx.restore()
                            }

                            ctx.beginPath()
                            ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.5)
                            ctx.lineTo(0, h * 0.5); ctx.lineTo(0, cut); ctx.closePath()
                            var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.5)
                            gloss.addColorStop(0, "rgba(255,255,255," + (0.05 + fp * 0.03) + ")")
                            gloss.addColorStop(1, "rgba(255,255,255,0.00)")
                            ctx.fillStyle = gloss; ctx.fill()

                            drawShape()
                            ctx.strokeStyle = fp > 0.5 ? "#c0f4f4" : "#3a3a3a"
                            ctx.lineWidth = 1
                            ctx.stroke()

                            if (fp > 0) {
                                drawShape()
                                ctx.strokeStyle = "rgba(150,245,245," + (fp * 0.9) + ")"
                                ctx.lineWidth = 1.4
                                ctx.stroke()
                            }
                        }
                    }

                    TextInput {
                        id: todoInput
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#e8e8e8"
                        font.pixelSize: 11; font.family: "monospace"
                        selectByMouse: true

                        Keys.onReturnPressed: {
                            calendarPopup.addTodo(text)
                            text = ""
                        }
                    }

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        text: "add a task..."
                        color: "#555555"
                        font.pixelSize: 11; font.family: "monospace"
                        visible: todoInput.text === "" && !todoInput.activeFocus
                    }
                }
            }

            Item { width: 1; height: 8 }

            Item {
                width: parent.width
                height: 148

                Text {
                    anchors.centerIn: parent
                    visible: calendarPopup.todos.length === 0
                    text: "no tasks yet"
                    color: "#444444"
                    font.pixelSize: 11; font.family: "monospace"
                }

                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentHeight: todoColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: todoColumn
                        width: parent.width
                        spacing: 3

                        Repeater {
                            model: calendarPopup.todos

                            delegate: Item {
                                id: todoRow
                                required property var modelData
                                required property int index
                                width: todoColumn.width
                                height: 30

                                GlowButton {
                                    id: todoRowGlow
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                                    height: 28
                                    cut: 6
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.ArrowCursor

                                    GlowButton {
                                        id: checkbox
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 6 }
                                        width: 16; height: 16
                                        cut: 3
                                        active: todoRow.modelData.done
                                        onClicked: calendarPopup.toggleTodo(todoRow.index)

                                        Text {
                                            anchors.centerIn: parent
                                            visible: todoRow.modelData.done
                                            text: "✓"
                                            color: "#0c1414"
                                            font.pixelSize: 9; font.bold: true
                                        }
                                    }

                                    Text {
                                        anchors { left: checkbox.right; right: removeBtn.left; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 6 }
                                        text: todoRow.modelData.text
                                        color: todoRow.modelData.done ? "#5a5a5a" : (todoRowGlow.hovered ? "#f0f0f0" : "#c8c8c8")
                                        font.pixelSize: 11; font.family: "monospace"
                                        font.strikeout: todoRow.modelData.done
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Text {
                                        id: removeBtn
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                                        text: "×"
                                        color: removeArea.containsMouse ? "#ff6b6b" : "#5a5a5a"
                                        font.pixelSize: 14; font.bold: true
                                        opacity: todoRowGlow.hovered ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        MouseArea {
                                            id: removeArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: calendarPopup.removeTodo(todoRow.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 10 }
        }
    }
}

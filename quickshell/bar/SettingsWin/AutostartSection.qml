import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../DivaPaint.js" as DivaPaint

Item {
    id: autostartSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: autostartSection.slideY }

    readonly property string scriptsDir: settingsWin ? settingsWin.repoDir + "/hypr/scripts" : ""
    property var entries: []
    property bool addOpen: false
    property string newName: ""
    property string newExec: ""
    property string addError: ""

    property bool browseOpen: false
    property string browseQuery: ""
    property var installedApps: []

    function loadInstalledApps() {
        try {
            autostartSection.installedApps = DesktopEntries.applications.values
                .filter(e => e && !e.noDisplay && e.name !== "" && e.execString !== "")
                .sort((a, b) => a.name.localeCompare(b.name))
        } catch (_) {
            autostartSection.installedApps = []
        }
    }

    property var filteredApps: {
        if (browseQuery.trim() === "") return installedApps
        var q = browseQuery.toLowerCase()
        return installedApps.filter(a => a.name.toLowerCase().indexOf(q) !== -1)
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
    }

    onSectionActiveChanged: if (sectionActive) refresh()

    Process {
        id: listProc
        command: ["bash", autostartSection.scriptsDir + "/list-autostart.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    autostartSection.entries = JSON.parse(text)
                } catch (e) {
                    autostartSection.entries = []
                }
            }
        }
    }

    Process {
        id: toggleProc
        command: []
        onExited: autostartSection.refresh()
    }

    function toggle(entry) {
        toggleProc.command = ["bash", autostartSection.scriptsDir + "/toggle-autostart.sh", entry.filename, entry.enabled ? "false" : "true"]
        toggleProc.running = false
        toggleProc.running = true
    }

    Process {
        id: removeProc
        command: []
        onExited: autostartSection.refresh()
    }

    function remove(entry) {
        removeProc.command = ["bash", autostartSection.scriptsDir + "/remove-autostart.sh", entry.filename]
        removeProc.running = false
        removeProc.running = true
    }

    Process {
        id: addProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                autostartSection.addOpen = false
                autostartSection.newName = ""
                autostartSection.newExec = ""
                autostartSection.addError = ""
                autostartSection.refresh()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) autostartSection.addError = text.trim()
            }
        }
    }

    function addEntry() {
        if (autostartSection.newName.trim() === "" || autostartSection.newExec.trim() === "") {
            autostartSection.addError = "name and command are required"
            return
        }
        autostartSection.addError = ""
        addProc.command = ["bash", autostartSection.scriptsDir + "/add-autostart.sh", autostartSection.newName.trim(), autostartSection.newExec.trim()]
        addProc.running = false
        addProc.running = true
    }

    function addFromApp(app) {
        autostartSection.addError = ""
        autostartSection.browseOpen = false
        autostartSection.browseQuery = ""
        addProc.command = ["bash", autostartSection.scriptsDir + "/add-autostart.sh", app.name, app.execString]
        addProc.running = false
        addProc.running = true
    }

    component AsBtn: Item {
        property string label: ""
        property bool active: false
        signal clicked()
        width: 68; height: 24

        Canvas {
            id: asBtnCanvas
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
            onPaint: DivaPaint.paintFacetPill(asBtnCanvas, parent.active ? 1.0 : Math.max(hp, 0), 5)
        }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: asBtnArea.containsMouse || parent.active ? "#ffffff" : "#999999"
            font.pixelSize: 9; font.family: "monospace"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: asBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: asBtnCanvas.hp = containsMouse ? 1.0 : 0.0
            onPositionChanged: mouse => {
                asBtnCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                asBtnCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
            }
            onClicked: parent.clicked()
        }
    }

    component AsToggle: Item {
        property bool checked: false
        signal toggled()
        width: 40; height: 22

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.checked ? "#39c5bb" : "#2a2a2a"
            border.color: parent.checked ? "#39c5bb" : "#3a3a3a"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: parent.checked ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    component AsField: Item {
        id: asField
        property string label: ""
        property alias text: fieldInput.text
        property string placeholder: ""
        width: parent ? parent.width : 0
        height: 32

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 70
            text: asField.label
            color: "#666666"
            font.pixelSize: 9; font.family: "monospace"
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 74 }
            height: 28
            color: "#242424"
            border.color: fieldInput.activeFocus ? "#39c5bb" : "#2e2e2e"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 130 } }

            TextInput {
                id: fieldInput
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                color: "#e0e0e0"
                font.pixelSize: 10; font.family: "monospace"
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    text: asField.placeholder
                    color: "#444444"
                    font.pixelSize: 10; font.family: "monospace"
                    verticalAlignment: Text.AlignVCenter
                    visible: fieldInput.text === "" && !fieldInput.activeFocus
                }
            }
        }
    }

    Item {
        id: asHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16; right: asHeaderActions.left; rightMargin: 10 }
            label: "autostart"
        }

        Row {
            id: asHeaderActions
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
            spacing: 8

            AsBtn {
                label: autostartSection.browseOpen ? "cancel" : "browse apps"
                active: autostartSection.browseOpen
                width: 92
                onClicked: {
                    autostartSection.browseOpen = !autostartSection.browseOpen
                    autostartSection.browseQuery = ""
                    if (autostartSection.browseOpen) {
                        autostartSection.addOpen = false
                        if (autostartSection.installedApps.length === 0) autostartSection.loadInstalledApps()
                    }
                }
            }

            AsBtn {
                id: asAddBtn
                label: autostartSection.addOpen ? "cancel" : "add command"
                active: autostartSection.addOpen
                width: 92
                onClicked: {
                    autostartSection.addOpen = !autostartSection.addOpen
                    autostartSection.addError = ""
                    if (autostartSection.addOpen) autostartSection.browseOpen = false
                }
            }
        }
    }

    Flickable {
        anchors { top: asHeader.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
        contentWidth: width
        contentHeight: asContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: asContent
            width: parent.width
            spacing: 12
            topPadding: 4
            leftPadding: 16
            rightPadding: 16
            bottomPadding: 16

            SectionCard {
                title: "new entry"
                visible: opacity > 0
                opacity: autostartSection.addOpen ? 1.0 : 0.0
                scale: autostartSection.addOpen ? 1.0 : 0.94
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

                Item {
                    width: parent.width
                    height: 108

                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        AsField {
                            label: "name"
                            placeholder: "My App"
                            text: autostartSection.newName
                            onTextChanged: autostartSection.newName = text
                        }
                        AsField {
                            label: "command"
                            placeholder: "/usr/bin/myapp --flag"
                            text: autostartSection.newExec
                            onTextChanged: autostartSection.newExec = text
                        }
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 16; bottom: parent.bottom; bottomMargin: 6 }
                        visible: autostartSection.addError !== ""
                        text: autostartSection.addError
                        color: "#ff6b6b"
                        font.pixelSize: 9; font.family: "monospace"
                    }

                    AsBtn {
                        anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 8 }
                        label: "create"
                        onClicked: autostartSection.addEntry()
                    }
                }
            }

            SectionCard {
                title: "installed apps"
                visible: opacity > 0
                opacity: autostartSection.browseOpen ? 1.0 : 0.0
                scale: autostartSection.browseOpen ? 1.0 : 0.94
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

                Item {
                    width: parent.width
                    height: 44

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                        height: 28
                        color: "#242424"
                        border.color: browseInput.activeFocus ? "#39c5bb" : "#2e2e2e"
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        TextInput {
                            id: browseInput
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e0e0e0"
                            font.pixelSize: 10; font.family: "monospace"
                            selectByMouse: true
                            focus: autostartSection.browseOpen
                            text: autostartSection.browseQuery
                            onTextChanged: autostartSection.browseQuery = text

                            Text {
                                anchors.fill: parent
                                text: "search installed apps..."
                                color: "#444444"
                                font.pixelSize: 10; font.family: "monospace"
                                verticalAlignment: Text.AlignVCenter
                                visible: browseInput.text === "" && !browseInput.activeFocus
                            }
                        }
                    }
                }

                Flickable {
                    width: parent.width
                    height: Math.min(220, appPickerList.contentHeight)
                    contentWidth: width
                    contentHeight: appPickerList.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ListView {
                        id: appPickerList
                        width: parent.width
                        height: contentHeight
                        interactive: false
                        model: autostartSection.filteredApps
                        delegate: Item {
                            id: appRow
                            required property var modelData
                            width: appPickerList.width
                            height: 40

                            Rectangle {
                                anchors { fill: parent; margins: 2 }
                                color: appRowArea.containsMouse ? "#242424" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            IconImage {
                                width: 20; height: 20
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                                source: "image://icon/" + (appRow.modelData.icon || "application-x-executable")
                            }

                            Text {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 40; rightMargin: 12 }
                                text: appRow.modelData.name
                                color: appRowArea.containsMouse ? "#ffffff" : "#cccccc"
                                font.pixelSize: 11; font.family: "monospace"
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: appRowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: autostartSection.addFromApp(appRow.modelData)
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: autostartSection.filteredApps.length === 0
                    text: "no matching apps"
                    color: "#444444"
                    font.pixelSize: 11; font.family: "monospace"
                    topPadding: 4
                    bottomPadding: 16
                }
            }

            SectionCard {
                title: "startup applications"

                Column {
                    id: entriesColumn
                    width: parent.width

                    add: Transition {
                        NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { properties: "scale"; from: 0.9; to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.4 }
                    }
                    populate: Transition {
                        NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    }
                    move: Transition {
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    Repeater {
                        model: autostartSection.entries
                        delegate: Item {
                            id: entryRow
                            required property var modelData
                            width: entriesColumn.width
                            height: 54

                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                            text: entryRow.modelData.enabled ? "󰐊" : "󰏤"
                            color: entryRow.modelData.enabled ? "#39c5bb" : "#666666"
                            font.pixelSize: 15
                        }

                        Column {
                            anchors { left: parent.left; right: entryActions.left; verticalCenter: parent.verticalCenter; leftMargin: 42; rightMargin: 10 }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: entryRow.modelData.name
                                color: "#cccccc"
                                font.pixelSize: 11; font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: entryRow.modelData.exec
                                color: "#666666"
                                font.pixelSize: 9; font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            id: entryActions
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 16 }
                            spacing: 10

                            AsBtn {
                                label: "remove"
                                width: 60
                                onClicked: autostartSection.remove(entryRow.modelData)
                            }

                            AsToggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: entryRow.modelData.enabled
                                onToggled: autostartSection.toggle(entryRow.modelData)
                            }
                        }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: autostartSection.entries.length === 0
                    text: "no autostart entries"
                    color: "#444444"
                    font.pixelSize: 11; font.family: "monospace"
                    topPadding: 20
                    bottomPadding: 12
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Widgets
import "./DivaPaint.js" as DivaPaint

Window {
    id: notifPopup
    property bool isOpen: false
    property var trackedNotifications
    property int notifCount: 0
    property var expandedGroups: ({})
    signal notifCountReset()
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 400
    visible: false

    function open(x, y) {
        notifPopup.x = x
        notifPopup.y = y
        isOpen = false
        visible = true
        notifOpenTimer.start()
    }

    function closePopup() { isOpen = false; notifCloseTimer.start() }
    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: notifOpenTimer; interval: 10; onTriggered: notifPopup.isOpen = true }
    Timer { id: notifCloseTimer; interval: 220; onTriggered: notifPopup.visible = false }

    function activateNotif(notif) {
        if (!notif || !notif.actions) return
        var acts = notif.actions.values ? notif.actions.values : notif.actions
        if (!acts || acts.length === 0) return
        var target = acts.find(a => a.identifier === "default") ?? acts[0]
        target.invoke()
    }

    function toggleGroup(appName) {
        var g = Object.assign({}, notifPopup.expandedGroups)
        g[appName] = !g[appName]
        notifPopup.expandedGroups = g
    }

    function buildGroups() {
        if (!notifPopup.trackedNotifications) return []
        var flat = notifPopup.trackedNotifications.values ?? []
        var order = []
        var byApp = {}
        for (var i = flat.length - 1; i >= 0; i--) {
            var n = flat[i]
            var key = n.appName || ""
            if (!byApp[key]) {
                byApp[key] = { appName: key, appIcon: n.appIcon, items: [] }
                order.push(key)
            }
            byApp[key].items.push(n)
        }
        return order.map(k => byApp[k])
    }

    PopupCard {
        id: notifRect
        anchors.fill: parent

        opacity: notifPopup.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: notifPopup.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: notifPopup.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: notifRect.width / 2; origin.y: 0; xScale: notifRect.scaleVal; yScale: notifRect.scaleVal },
            Translate { y: notifRect.slideY }
        ]

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 36

                Item {
                    id: clearAllBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                    width: 58; height: 22
                    visible: notifPopup.notifCount > 0

                    Canvas {
                        id: clearAllCanvas
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
                        onPaint: DivaPaint.paintFacetPill(clearAllCanvas, hoverProgress, 4)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "clear all"
                        color: clearAllArea.containsMouse ? "#ffffff" : "#999999"
                        font.pixelSize: 9; font.family: "monospace"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    MouseArea {
                        id: clearAllArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: clearAllCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                        onPositionChanged: mouse => {
                            clearAllCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                            clearAllCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                        }
                        onClicked: {
                            notifPopup.closePopup()
                            try {
                                var notifs = notifPopup.trackedNotifications.values
                                for (var i = notifs.length - 1; i >= 0; i--) notifs[i].dismiss()
                            } catch (e) {}
                            notifPopup.notifCountReset()
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 50
                visible: notifPopup.notifCount === 0
                Text {
                    anchors.centerIn: parent
                    text: "no notifications"
                    color: "#444444"; font.pixelSize: 11; font.family: "monospace"
                }
            }

            ListView {
                id: notifListView
                width: parent.width
                height: parent.height - 37
                clip: true
                visible: notifPopup.notifCount > 0
                model: notifPopup.buildGroups()
                spacing: 3
                topMargin: 5
                bottomMargin: 5

                Connections {
                    target: notifPopup.trackedNotifications
                    function onValuesChanged() { notifListView.model = notifPopup.buildGroups() }
                }
                Connections {
                    target: notifPopup
                    function onExpandedGroupsChanged() { notifListView.model = notifPopup.buildGroups() }
                }

                removeDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: groupDelegate
                    required property var modelData
                    property bool expanded: modelData.items.length > 1 && !!notifPopup.expandedGroups[modelData.appName]
                    property var latest: modelData.items[0]
                    width: notifListView.width
                    implicitHeight: headerItem.height + (expanded ? childrenCol.height : 0)
                    height: implicitHeight
                    clip: true

                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Item {
                        id: swipeItem
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: parent.height
                        width: parent.width - 8
                        x: swipeOffset + 4
                        opacity: Math.max(0, 1.0 - swipeOffset / 120)

                        property real swipeOffset: 0

                        Column {
                            id: contentCol
                            width: parent.width

                            Item {
                                id: headerItem
                                width: parent.width
                                height: 66

                                Canvas {
                                    id: notifCanvas
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
                                    onPaint: DivaPaint.paintFacetPill(notifCanvas, hoverProgress, 5)
                                }

                                Row {
                                    anchors { left: parent.left; right: dismissItem.left; top: parent.top; bottom: parent.bottom; margins: 10; rightMargin: 4 }
                                    spacing: 8

                                    IconImage {
                                        width: 22; height: 22
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: groupDelegate.modelData.appIcon !== "" ? "image://icon/" + groupDelegate.modelData.appIcon : ""
                                        mipmap: true
                                        visible: groupDelegate.modelData.appIcon !== ""
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - (groupDelegate.modelData.appIcon !== "" ? 30 : 0) - (countBadge.visible ? countBadge.width + 6 : 0)
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: groupDelegate.latest.summary
                                            color: notifItemArea.containsMouse ? "#ffffff" : "#d0d0d0"
                                            font.pixelSize: 12; font.family: "monospace"
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 130 } }
                                        }

                                        Text {
                                            width: parent.width
                                            text: groupDelegate.latest.body
                                            color: notifItemArea.containsMouse ? "#bbbbbb" : "#666666"
                                            font.pixelSize: 10; font.family: "monospace"
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            visible: groupDelegate.latest.body !== ""
                                            Behavior on color { ColorAnimation { duration: 130 } }
                                        }
                                    }

                                    Rectangle {
                                        id: countBadge
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: groupDelegate.modelData.items.length > 1
                                        width: countText.width + 12; height: 16; radius: 8
                                        color: groupDelegate.expanded ? "#39c5bb" : "#4a4a4a"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: "+" + (groupDelegate.modelData.items.length - 1)
                                            color: "#ffffff"
                                            font.pixelSize: 9; font.family: "monospace"
                                        }
                                    }
                                }

                                Item {
                                    id: dismissItem
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                                    width: 20; height: 20; z: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: dismissArea.containsMouse ? "#ffffff" : "#555555"
                                        font.pixelSize: 16
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: dismissArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var items = groupDelegate.modelData.items
                                            for (var i = items.length - 1; i >= 0; i--) items[i].dismiss()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: notifItemArea
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: notifCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                    onPositionChanged: mouse => {
                                        notifCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                        notifCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                    }
                                    onClicked: {
                                        if (groupDelegate.modelData.items.length > 1) {
                                            notifPopup.toggleGroup(groupDelegate.modelData.appName)
                                        } else {
                                            notifPopup.activateNotif(groupDelegate.latest)
                                        }
                                    }
                                }
                            }

                            Column {
                                id: childrenCol
                                width: parent.width
                                visible: groupDelegate.expanded
                                Repeater {
                                    model: groupDelegate.expanded ? groupDelegate.modelData.items.slice(1) : []
                                    delegate: Item {
                                        id: childItem
                                        required property var modelData
                                        width: childrenCol.width
                                        height: 44

                                        Rectangle {
                                            anchors { fill: parent; margins: 2 }
                                            radius: 4
                                            color: childArea.containsMouse ? "#333333" : "transparent"
                                            Behavior on color { ColorAnimation { duration: 130 } }

                                            Row {
                                                anchors { left: parent.left; right: childDismiss.left; top: parent.top; bottom: parent.bottom; margins: 8; rightMargin: 4 }
                                                spacing: 8

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width
                                                    spacing: 2
                                                    Text {
                                                        width: parent.width
                                                        text: childItem.modelData.summary
                                                        color: "#c0c0c0"
                                                        font.pixelSize: 11; font.family: "monospace"
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        text: childItem.modelData.body
                                                        color: "#666666"
                                                        font.pixelSize: 9; font.family: "monospace"
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                        visible: childItem.modelData.body !== ""
                                                    }
                                                }
                                            }

                                            Item {
                                                id: childDismiss
                                                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                                                width: 18; height: 18; z: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "×"
                                                    color: childDismissArea.containsMouse ? "#ffffff" : "#555555"
                                                    font.pixelSize: 14
                                                }
                                                MouseArea {
                                                    id: childDismissArea
                                                    anchors.fill: parent; hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: childItem.modelData.dismiss()
                                                }
                                            }

                                            MouseArea {
                                                id: childArea
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: notifPopup.activateNotif(childItem.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DragHandler {
                        id: notifSwipe
                        target: null
                        xAxis.enabled: true
                        xAxis.minimum: 0
                        yAxis.enabled: false
                        onTranslationChanged: if (active) swipeItem.swipeOffset = Math.max(0, translation.x)
                        onActiveChanged: {
                            if (!active) {
                                if (swipeItem.swipeOffset > 80) {
                                    var items = groupDelegate.modelData.items
                                    for (var i = items.length - 1; i >= 0; i--) items[i].dismiss()
                                } else {
                                    snapBackAnim.start()
                                }
                            }
                        }
                    }

                    NumberAnimation {
                        id: snapBackAnim
                        target: swipeItem
                        property: "swipeOffset"
                        to: 0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}

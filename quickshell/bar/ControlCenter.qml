import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "./DivaPaint.js" as DivaPaint

Window {
    id: controlCenter
    property bool isOpen: false
    property string activeTab: "audio"

    property real brightness: 1
    property bool brightnessAvailable: false
    signal brightnessMoved(real v)

    property var trackedNotifications
    property int notifCount: 0
    property var expandedGroups: ({})
    signal notifCountReset()

    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 320
    height: 460
    visible: false

    function open(x, y) {
        controlCenter.x = x
        controlCenter.y = y
        isOpen = false
        visible = true
        ccOpenTimer.start()
    }

    function closePopup() {
        isOpen = false
        ccCloseTimer.start()
    }

    onClosing: close => { if (isOpen) { close.accepted = false; closePopup() } }

    Timer { id: ccOpenTimer; interval: 10; onTriggered: controlCenter.isOpen = true }
    Timer { id: ccCloseTimer; interval: 220; onTriggered: controlCenter.visible = false }

    property bool sliderActive: false
    function markSliderActive() {
        sliderActive = true
        sliderActiveResetTimer.restart()
    }
    Timer { id: sliderActiveResetTimer; interval: 300; onTriggered: controlCenter.sliderActive = false }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    property var playbackStreams: Pipewire.ready
        ? Pipewire.nodes.values.filter(function(n) { return n.isStream && (n.type & PwNodeType.AudioOutStream) })
        : []

    function activateNotif(notif) {
        if (!notif || !notif.actions) return
        var acts = notif.actions.values ? notif.actions.values : notif.actions
        if (!acts || acts.length === 0) return
        var target = acts.find(a => a.identifier === "default") ?? acts[0]
        target.invoke()
    }

    function toggleGroup(appName) {
        var g = Object.assign({}, controlCenter.expandedGroups)
        g[appName] = !g[appName]
        controlCenter.expandedGroups = g
    }

    function buildGroups() {
        if (!controlCenter.trackedNotifications) return []
        var flat = controlCenter.trackedNotifications.values ?? []
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

    component VolumeSlider: Item {
        id: volSlider
        property real value: 0
        property bool muted: false
        property color accent: "#39c5bb"
        readonly property bool hovered: sliderArea.containsMouse || sliderArea.pressed
        signal moved(real v)
        height: 20

        Rectangle {
            id: sliderTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 2.5
            color: "#1c1c1c"
            border.color: "#333333"
            border.width: 1

            Rectangle {
                id: sliderFill
                width: sliderTrack.width * Math.max(0, Math.min(1, volSlider.value))
                height: parent.height
                radius: parent.radius
                color: volSlider.muted ? "#555555" : volSlider.accent
                Behavior on width { NumberAnimation { duration: 60 } }

                layer.enabled: !volSlider.muted
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: volSlider.accent
                    shadowBlur: volSlider.hovered ? 0.7 : 0.4
                    shadowOpacity: volSlider.hovered ? 0.85 : 0.45
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: volSlider.hovered ? 20 : 10
                    autoPaddingEnabled: true
                }
            }

            Rectangle {
                id: sliderThumb
                x: sliderFill.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 11; height: 11; radius: 5.5
                color: "#ffffff"
                border.color: volSlider.muted ? "#555555" : volSlider.accent
                border.width: 1.5
                scale: volSlider.hovered ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
        }

        MouseArea {
            id: sliderArea
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function updateFromX(mx) {
                controlCenter.markSliderActive()
                moved(Math.max(0, Math.min(1, mx / width)))
            }
            onPressed: mouse => updateFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
            onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                controlCenter.markSliderActive()
                moved(Math.max(0, Math.min(1, value + step)))
            }
        }
    }

    component MuteBtn: Item {
        id: muteBtn
        property bool muted: false
        signal toggled()
        width: 26; height: 26

        Canvas {
            id: muteBtnCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: DivaPaint.paintFacetPill(muteBtnCanvas, hp, 5, muteBtn.muted ? DivaPaint.ACCENT_RED : DivaPaint.ACCENT_TEAL)
        }

        Text {
            anchors.centerIn: parent
            text: muteBtn.muted ? "󰝟" : "󰕾"
            color: muteArea.containsMouse ? "#ffffff" : (muteBtn.muted ? "#ff8a8a" : "#999999")
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: muteBtnCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: muteBtn.toggled()
        }
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

    component TabBtn: Item {
        id: tabBtn
        property string label: ""
        property bool active: false
        property bool showBadge: false
        signal clicked()
        height: 30

        Canvas {
            id: tabCanvas
            anchors.fill: parent
            property real hp: 0.0
            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            onHpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: tabBtn
                function onActiveChanged() { tabCanvas.requestPaint() }
            }
            onPaint: DivaPaint.paintFacetPill(tabCanvas, tabBtn.active ? 1.0 : tabCanvas.hp, 6)
        }

        Text {
            anchors.centerIn: parent
            text: tabBtn.label
            color: tabBtn.active || tabArea.containsMouse ? "#ffffff" : "#999999"
            font.pixelSize: 10; font.family: "monospace"
            font.letterSpacing: 1
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            visible: tabBtn.showBadge
            anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 10 }
            width: 7; height: 7; radius: 3.5
            color: "#ff4444"
        }

        MouseArea {
            id: tabArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: tabCanvas.hp = containsMouse ? 1.0 : 0.0
            onClicked: tabBtn.clicked()
        }
    }

    Item {
        id: ccRect
        anchors.fill: parent

        opacity: controlCenter.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: controlCenter.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: controlCenter.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: ccRect.width / 2; origin.y: 0; xScale: ccRect.scaleVal; yScale: ccRect.scaleVal },
            Translate { y: ccRect.slideY }
        ]

        Canvas {
            id: ccCardCanvas
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                var w = width, h = height, cut = 12
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

        Column {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            Item {
                width: parent.width
                height: 40

                Row {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 6; bottomMargin: 6 }
                    spacing: 6

                    TabBtn {
                        width: (parent.width - 6) / 2
                        height: parent.height
                        label: "audio"
                        active: controlCenter.activeTab === "audio"
                        onClicked: controlCenter.activeTab = "audio"
                    }

                    TabBtn {
                        width: (parent.width - 6) / 2
                        height: parent.height
                        label: "notifications"
                        active: controlCenter.activeTab === "notifications"
                        showBadge: controlCenter.notifCount > 0
                        onClicked: controlCenter.activeTab = "notifications"
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: "#2a2a2a"
            }

            Item {
                id: tabViewport
                width: parent.width
                height: parent.height - 41
                clip: true

                Column {
                    id: audioTab
                    width: tabViewport.width
                    height: tabViewport.height
                    spacing: 0
                    visible: opacity > 0
                    opacity: controlCenter.activeTab === "audio" ? 1.0 : 0.0
                    x: controlCenter.activeTab === "audio" ? 0 : -tabViewport.width * 0.25
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Item {
                        width: parent.width
                        height: 60

                        MuteBtn {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                            muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                            onToggled: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                        }

                        VolumeSlider {
                            anchors { left: parent.left; right: masterPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 50; rightMargin: 10 }
                            value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
                            muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
                            onMoved: v => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v }
                        }

                        Text {
                            id: masterPctText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                            color: "#999999"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }

                    Item {
                        width: parent.width
                        height: 60
                        visible: controlCenter.brightnessAvailable

                        Item {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                            width: 26; height: 26

                            Canvas {
                                anchors.fill: parent
                                onPaint: DivaPaint.paintFacetPill(this, 0.0, 5, DivaPaint.ACCENT_AMBER)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰃟"
                                color: "#f5c542"
                                font.pixelSize: 14
                            }
                        }

                        VolumeSlider {
                            anchors { left: parent.left; right: brightnessPctText.left; verticalCenter: parent.verticalCenter; leftMargin: 50; rightMargin: 10 }
                            value: controlCenter.brightness
                            accent: "#f5c542"
                            onMoved: v => controlCenter.brightnessMoved(v)
                        }

                        Text {
                            id: brightnessPctText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(controlCenter.brightness * 100) + "%"
                            color: "#999999"
                            font.pixelSize: 10; font.family: "monospace"
                        }
                    }

                    SectionBanner { label: "applications" }
                    Item { width: 1; height: 8 }

                    ListView {
                        width: parent.width
                        height: parent.height - 60 - (controlCenter.brightnessAvailable ? 60 : 0) - 26 - 8
                        clip: true
                        model: controlCenter.playbackStreams
                        spacing: 2

                        delegate: Item {
                            id: streamRow
                            required property var modelData
                            property string appName: streamRow.modelData.properties["application.name"] || streamRow.modelData.description || streamRow.modelData.name
                            property var appEntry: DesktopEntries.heuristicLookup(streamRow.appName)
                            width: ListView.view.width
                            height: 48

                            Rectangle {
                                anchors { left: parent.left; top: parent.top; leftMargin: 10; topMargin: 4 }
                                width: 20; height: 20
                                radius: 4
                                color: "#1c1c1c"
                                border.color: "#333333"
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 14; height: 14
                                    source: streamRow.appEntry && streamRow.appEntry.icon !== "" ? "image://icon/" + streamRow.appEntry.icon : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !streamRow.appEntry || streamRow.appEntry.icon === ""
                                    text: "󰝚"
                                    color: "#666666"
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors { left: parent.left; top: parent.top; leftMargin: 36; topMargin: 4; right: parent.right; rightMargin: 14 }
                                text: streamRow.appName
                                color: "#cccccc"
                                font.pixelSize: 10; font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Item {
                                id: streamControlRow
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
                                height: 20

                                MuteBtn {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                    width: 22; height: 18
                                    muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                    onToggled: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                                }

                                VolumeSlider {
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 38; rightMargin: 44 }
                                    value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
                                    muted: streamRow.modelData.audio ? streamRow.modelData.audio.muted : false
                                    onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
                                }

                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                                    width: 34
                                    horizontalAlignment: Text.AlignRight
                                    text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                                    color: "#666666"
                                    font.pixelSize: 9; font.family: "monospace"
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: controlCenter.playbackStreams.length === 0
                            text: "nothing playing"
                            color: "#444444"
                            font.pixelSize: 11; font.family: "monospace"
                        }
                    }
                }

                Column {
                    id: notifTab
                    width: tabViewport.width
                    height: tabViewport.height
                    spacing: 0
                    visible: opacity > 0
                    opacity: controlCenter.activeTab === "notifications" ? 1.0 : 0.0
                    x: controlCenter.activeTab === "notifications" ? 0 : tabViewport.width * 0.25
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Item {
                        width: parent.width
                        height: 36

                        Item {
                            id: clearAllBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                            width: 58; height: 22
                            visible: controlCenter.notifCount > 0

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
                                    controlCenter.closePopup()
                                    try {
                                        var notifs = controlCenter.trackedNotifications.values
                                        for (var i = notifs.length - 1; i >= 0; i--) notifs[i].dismiss()
                                    } catch (e) {}
                                    controlCenter.notifCountReset()
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 50
                        visible: controlCenter.notifCount === 0
                        Text {
                            anchors.centerIn: parent
                            text: "no notifications"
                            color: "#444444"; font.pixelSize: 11; font.family: "monospace"
                        }
                    }

                    ListView {
                        id: notifListView
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 24
                        height: parent.height - 37
                        clip: true
                        visible: controlCenter.notifCount > 0
                        model: controlCenter.buildGroups()
                        spacing: 3
                        topMargin: 5
                        bottomMargin: 5

                        Connections {
                            target: controlCenter.trackedNotifications
                            function onValuesChanged() { notifListView.model = controlCenter.buildGroups() }
                        }
                        Connections {
                            target: controlCenter
                            function onExpandedGroupsChanged() { notifListView.model = controlCenter.buildGroups() }
                        }

                        removeDisplaced: Transition {
                            NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: groupDelegate
                            required property var modelData
                            property bool expanded: modelData.items.length > 1 && !!controlCenter.expandedGroups[modelData.appName]
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
                                                    controlCenter.toggleGroup(groupDelegate.modelData.appName)
                                                } else {
                                                    controlCenter.activateNotif(groupDelegate.latest)
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
                                                        onClicked: controlCenter.activateNotif(childItem.modelData)
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
    }
}

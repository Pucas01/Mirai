import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "./DivaPaint.js" as DivaPaint

Window {
    id: trayMenuWin
    property var targetItem: null
    property bool isOpen: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    width: 180
    height: menuCol.implicitHeight + 2
    visible: false

    function open(x, y) {
        trayMenuWin.x = x
        trayMenuWin.y = y
        isOpen = false
        visible = true
        openTimer.start()
    }

    function closeMenu() {
        isOpen = false
        closeTimer.start()
    }

    onClosing: close => {
        if (isOpen) {
            close.accepted = false
            closeMenu()
        }
    }

    Timer {
        id: openTimer
        interval: 10
        onTriggered: trayMenuWin.isOpen = true
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: trayMenuWin.visible = false
    }

    QsMenuOpener {
        id: menuOpener
        menu: trayMenuWin.targetItem ? trayMenuWin.targetItem.menu : null
    }

    PanelBackground {
        id: menuRect
        anchors.fill: parent

        opacity: trayMenuWin.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real scaleVal: trayMenuWin.isOpen ? 1.0 : 0.88
        Behavior on scaleVal { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.35 } }

        property real slideY: trayMenuWin.isOpen ? 0 : -8
        Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: [
            Scale { origin.x: menuRect.width / 2; origin.y: 0; xScale: menuRect.scaleVal; yScale: menuRect.scaleVal },
            Translate { y: menuRect.slideY }
        ]

        Column {
            id: menuCol
            width: parent.width - 2
            x: 1
            y: 5
            bottomPadding: 5

            Column {
                width: parent.width
                spacing: 3
                topPadding: 5
                bottomPadding: 5

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        required property var modelData
                        width: menuCol.width
                        height: modelData.isSeparator ? 8 : 30

                        Rectangle {
                            visible: modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 20
                            height: 1
                            color: "#39c5bb"
                            opacity: 1
                        }

                        Item {
                            visible: !modelData.isSeparator
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }

                            Canvas {
                                id: entryCanvas
                                anchors.fill: parent
                                property real hoverProgress: 0.0
                                Behavior on hoverProgress { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                onHoverProgressChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                onPaint: DivaPaint.paintFacetPill(getContext("2d"), width, height, hoverProgress, 5)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                text: modelData.text
                                color: !modelData.enabled ? "#444444" : entryArea.containsMouse ? "#ffffff" : "#e0e0e0"
                                Behavior on color { ColorAnimation { duration: 130 } }
                                font.pixelSize: 12
                                font.family: "monospace"
                                elide: Text.ElideRight
                                width: parent.width - 20
                            }

                            MouseArea {
                                id: entryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.enabled
                                onContainsMouseChanged: entryCanvas.hoverProgress = containsMouse ? 1.0 : 0.0
                                onClicked: {
                                    modelData.triggered()
                                    trayMenuWin.closeMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

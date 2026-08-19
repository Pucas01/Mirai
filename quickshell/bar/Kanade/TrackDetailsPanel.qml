import QtQuick
import ".."
import "../DivaPaint.js" as DivaPaint

Item {
    id: detailsPanel
    property var kanadeWin: null
    readonly property bool isOpen: kanadeWin && kanadeWin.selectedTrack !== null
    width: 260
    clip: false

    Rectangle {
        id: panelBody
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#2a2a2a"
        border.width: 1

        opacity: detailsPanel.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        property real slideX: detailsPanel.isOpen ? 0 : 24
        Behavior on slideX { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transform: Translate { x: panelBody.slideX }

        visible: opacity > 0.01

        Item {
            id: closeRow
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
            height: 20

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "track info"
                color: "#666666"
                font.pixelSize: 9; font.family: "monospace"
            }

            GlowButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 22; height: 18
                cut: 4
                accent: DivaPaint.ACCENT_RED
                onClicked: kanadeWin.closeTrackDetails()

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: parent.hovered ? "#ffffff" : "#999999"
                    font.pixelSize: 10
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }

        Rectangle {
            id: coverArt
            anchors { top: closeRow.bottom; left: parent.left; right: parent.right; margins: 16; topMargin: 10 }
            height: width
            color: "#111111"
            border.color: "#2a2a2a"
            border.width: 1

            Image {
                anchors.fill: parent
                anchors.margins: 1
                visible: kanadeWin && !kanadeWin.selectedCoverMissing && kanadeWin.selectedCoverPath !== ""
                source: kanadeWin && kanadeWin.selectedCoverPath !== "" ? "file://" + kanadeWin.selectedCoverPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Text {
                anchors.centerIn: parent
                visible: kanadeWin && kanadeWin.selectedCoverMissing
                text: "󰝚"
                color: "#3a3a3a"
                font.pixelSize: 48
            }
        }

        Column {
            anchors { top: coverArt.bottom; left: parent.left; right: parent.right; margins: 16; topMargin: 14 }
            spacing: 14

            Column {
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    text: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.trackTitle(kanadeWin.selectedTrack) : ""
                    color: "#ffffff"
                    font.pixelSize: 13; font.family: "monospace"; font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.trackArtist(kanadeWin.selectedTrack) : ""
                    color: "#999999"
                    font.pixelSize: 11; font.family: "monospace"
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            Column {
                width: parent.width
                spacing: 8

                component InfoRow: Column {
                    property string label: ""
                    property string value: ""
                    visible: value !== ""
                    width: parent.width
                    spacing: 1
                    Text { text: label; color: "#555555"; font.pixelSize: 9; font.family: "monospace" }
                    Text { text: value; color: "#cccccc"; font.pixelSize: 11; font.family: "monospace"; wrapMode: Text.WrapAnywhere; width: parent.width }
                }

                InfoRow {
                    label: "album"
                    value: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.trackAlbum(kanadeWin.selectedTrack) : ""
                }
                InfoRow {
                    label: "length"
                    value: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.formatDuration(kanadeWin.selectedTrack.duration) : ""
                }
                InfoRow {
                    label: "track no."
                    value: kanadeWin && kanadeWin.selectedTrack && kanadeWin.trackNumber(kanadeWin.selectedTrack) > 0 ? String(kanadeWin.trackNumber(kanadeWin.selectedTrack)) : ""
                }
                InfoRow {
                    label: "genre"
                    value: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.tag(kanadeWin.selectedTrack, "genre") : ""
                }
                InfoRow {
                    label: "format"
                    value: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.selectedTrack.path.split(".").pop().toUpperCase() : ""
                }
                InfoRow {
                    label: "path"
                    value: kanadeWin && kanadeWin.selectedTrack ? kanadeWin.selectedTrack.path : ""
                }
            }
        }
    }
}

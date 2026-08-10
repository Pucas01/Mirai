import QtQuick
import Quickshell.Io

Item {
    id: aboutSection
    property var settingsWin: null
    anchors.fill: parent
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real slideY: sectionActive ? 0 : 10
    Behavior on slideY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    transform: Translate { y: aboutSection.slideY }

    Process {
        id: openRepoProc
        command: ["xdg-open", "https://github.com/Pucas01/Mirai"]
        running: false
    }

    Item {
        id: aboutHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        SectionBanner {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
            label: "about"
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -16
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Mirai"
            color: "#39c5bb"
            font.pixelSize: 34; font.bold: true; font.family: "monospace"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "My personal quickshell, i like it very much"
            color: "#999999"
            font.pixelSize: 11; font.family: "monospace"
        }

        Item { width: 1; height: 10 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "built by Pucas01"
            color: "#666666"
            font.pixelSize: 10; font.family: "monospace"
        }

        Text {
            id: repoLinkText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "github.com/Pucas01/Mirai"
            color: repoLinkArea.containsMouse ? "#80e0e0" : "#39c5bb"
            font.pixelSize: 10; font.family: "monospace"
            font.underline: repoLinkArea.containsMouse
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea {
                id: repoLinkArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { openRepoProc.running = false; openRepoProc.running = true }
            }
        }
    }
}

import QtQuick

Item {
    property string label: ""
    height: 26

    Text {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: parent.label.toUpperCase()
        color: "#ffffff"
        font.pixelSize: 11; font.family: "Orbitron"; font.bold: true
        font.letterSpacing: 2
    }
}

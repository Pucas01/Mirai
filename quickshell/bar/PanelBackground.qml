import QtQuick

Rectangle {
    id: panelBackground
    default property alias content: panelContent.children
    property bool showBorder: true

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0;  color: "#3d3d3d" }
        GradientStop { position: 0.06; color: "#2c2c2c" }
        GradientStop { position: 0.4;  color: "#232323" }
        GradientStop { position: 1.0;  color: "#181818" }
    }
    border.color: panelBackground.showBorder ? "#39c5bb" : "transparent"
    border.width: 1

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }
        height: 1
        color: "#5a5a5a"
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 2 }
        height: 4
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#50505050" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
    }

    Item {
        id: panelContent
        anchors.fill: parent
    }
}

import QtQuick
import "../DivaPaint.js" as DivaPaint

Item {
    id: reposSection
    property var githubWin: null
    property bool sectionActive: false
    opacity: sectionActive ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    anchors.fill: parent

    property string searchText: ""
    readonly property var filteredRepos: {
        if (!githubWin) return []
        if (searchText === "") return githubWin.repos
        var q = searchText.toLowerCase()
        return githubWin.repos.filter(function(r) { return r.nameWithOwner.toLowerCase().includes(q) })
    }

    function languageColor(name) {
        var colors = {
            "QML": "#44a51c", "JavaScript": "#f1e05a", "TypeScript": "#3178c6",
            "Rust": "#dea584", "Python": "#3572A5", "Lua": "#000080",
            "Luau": "#00a2ff", "C++": "#f34b7d", "C": "#555555",
            "Game Maker Language": "#71b417", "Shell": "#89e051", "HTML": "#e34c26"
        }
        return colors[name] || "#888888"
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
        height: 24

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: reposSection.filteredRepos.length + (reposSection.filteredRepos.length === 1 ? " repository" : " repositories")
            color: "#888888"
            font.pixelSize: 11; font.family: "monospace"; font.bold: true
        }

        TextInput {
            id: repoSearch
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 160
            color: "#e0e0e0"
            font.pixelSize: 10; font.family: "monospace"
            selectByMouse: true
            onTextChanged: reposSection.searchText = text

            Text {
                anchors.fill: parent
                visible: repoSearch.text === "" && !repoSearch.activeFocus
                text: "search repos..."
                color: "#444444"
                font.pixelSize: 10; font.family: "monospace"
            }
        }
    }

    ListView {
        id: repoList
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 12 }
        clip: true
        spacing: 6
        model: reposSection.filteredRepos

        delegate: Item {
            id: repoRow
            required property var modelData
            width: repoList.width
            height: 46

            Canvas {
                id: repoRowCanvas
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
                onPaint: DivaPaint.paintFacetPill(repoRowCanvas, repoRowCanvas.hp, 6)
            }

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14; right: repoMeta.left; rightMargin: 8 }
                spacing: 6

                Text {
                    text: repoRow.modelData.isPrivate ? "󰌾" : "󰊢"
                    color: "#888888"
                    font.pixelSize: 12
                }

                Column {
                    spacing: 2
                    Text {
                        text: repoRow.modelData.nameWithOwner
                        color: "#e0e0e0"
                        font.pixelSize: 12; font.family: "monospace"
                    }
                    Text {
                        text: "updated " + githubWin.timeAgo(repoRow.modelData.updatedAt)
                        color: "#555555"
                        font.pixelSize: 9; font.family: "monospace"
                    }
                }
            }

            Row {
                id: repoMeta
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                spacing: 12

                Row {
                    visible: repoRow.modelData.primaryLanguage !== null
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: reposSection.languageColor(repoRow.modelData.primaryLanguage ? repoRow.modelData.primaryLanguage.name : "")
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: repoRow.modelData.primaryLanguage ? repoRow.modelData.primaryLanguage.name : ""
                        color: "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }

                Row {
                    visible: repoRow.modelData.stargazerCount > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰓎"
                        color: "#e0c05a"
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: repoRow.modelData.stargazerCount
                        color: "#999999"
                        font.pixelSize: 10; font.family: "monospace"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: repoRowCanvas.hp = containsMouse ? 1.0 : 0.0
                onPositionChanged: mouse => {
                    repoRowCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                    repoRowCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                }
                onClicked: githubWin.openUrl(repoRow.modelData.url)
            }
        }
    }

    Text {
        anchors.centerIn: repoList
        visible: !githubWin.reposLoading && reposSection.filteredRepos.length === 0
        text: reposSection.searchText !== "" ? "no matching repositories" : "no repositories found"
        color: "#444444"
        font.pixelSize: 12; font.family: "monospace"
    }

    Text {
        anchors.centerIn: repoList
        visible: githubWin.reposLoading && reposSection.filteredRepos.length === 0
        text: "loading..."
        color: "#39c5bb"
        font.pixelSize: 12; font.family: "monospace"
    }
}

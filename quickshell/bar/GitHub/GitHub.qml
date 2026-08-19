import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../DivaPaint.js" as DivaPaint

Window {
    id: githubWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "github"
    color: "transparent"
    width: 820
    height: 600
    visible: false

    property string section: "pulls"

    property bool prsLoading: false
    property var myPrs: []
    property bool reviewsLoading: false
    property var reviewPrs: []
    property bool reposLoading: false
    property var repos: []
    property bool notifsLoading: false
    property var notifications: []
    property string ghError: ""

    function refreshAll() {
        refreshMyPrs()
        refreshReviewPrs()
        refreshRepos()
        refreshNotifications()
    }

    function refreshMyPrs() {
        githubWin.prsLoading = true
        myPrsProc.running = false
        myPrsProc.running = true
    }

    function refreshReviewPrs() {
        githubWin.reviewsLoading = true
        reviewPrsProc.running = false
        reviewPrsProc.running = true
    }

    function refreshRepos() {
        githubWin.reposLoading = true
        reposProc.running = false
        reposProc.running = true
    }

    function refreshNotifications() {
        githubWin.notifsLoading = true
        notifsProc.running = false
        notifsProc.running = true
    }

    function timeAgo(isoString) {
        if (!isoString) return ""
        var then = new Date(isoString).getTime()
        var now = Date.now()
        var diffSec = Math.max(0, Math.floor((now - then) / 1000))
        if (diffSec < 60) return diffSec + "s ago"
        var diffMin = Math.floor(diffSec / 60)
        if (diffMin < 60) return diffMin + "m ago"
        var diffHr = Math.floor(diffMin / 60)
        if (diffHr < 24) return diffHr + "h ago"
        var diffDay = Math.floor(diffHr / 24)
        if (diffDay < 30) return diffDay + "d ago"
        var diffMonth = Math.floor(diffDay / 30)
        if (diffMonth < 12) return diffMonth + "mo ago"
        return Math.floor(diffMonth / 12) + "y ago"
    }

    Component.onCompleted: refreshAll()

    onVisibleChanged: if (visible) refreshAll()

    Timer {
        interval: 120000
        running: true
        repeat: true
        onTriggered: if (githubWin.visible) githubWin.refreshAll()
    }

    Process {
        id: myPrsProc
        command: ["gh", "search", "prs", "--author", "@me", "--state", "open", "--sort", "updated",
            "--json", "title,repository,number,isDraft,url,updatedAt", "--limit", "50"]
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.prsLoading = false
                try { githubWin.myPrs = JSON.parse(text) } catch (e) { githubWin.myPrs = [] }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") githubWin.ghError = text.trim() }
        }
    }

    Process {
        id: reviewPrsProc
        command: ["gh", "search", "prs", "--review-requested", "@me", "--state", "open", "--sort", "updated",
            "--json", "title,repository,number,isDraft,url,updatedAt", "--limit", "50"]
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.reviewsLoading = false
                try { githubWin.reviewPrs = JSON.parse(text) } catch (e) { githubWin.reviewPrs = [] }
            }
        }
    }

    Process {
        id: reposProc
        command: ["gh", "repo", "list", "--json", "name,nameWithOwner,stargazerCount,updatedAt,primaryLanguage,isPrivate,url", "--limit", "100"]
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.reposLoading = false
                try {
                    var list = JSON.parse(text)
                    list.sort(function(a, b) { return new Date(b.updatedAt) - new Date(a.updatedAt) })
                    githubWin.repos = list
                } catch (e) { githubWin.repos = [] }
            }
        }
    }

    Process {
        id: notifsProc
        command: ["gh", "api", "notifications",
            "--jq", "[.[] | {reason: .reason, repo: .repository.full_name, title: .subject.title, type: .subject.type, updatedAt: .updated_at, unread: .unread}]"]
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.notifsLoading = false
                try { githubWin.notifications = JSON.parse(text) } catch (e) { githubWin.notifications = [] }
            }
        }
    }

    Process {
        id: openUrlProc
        command: ["true"]
    }

    function openUrl(url) {
        openUrlProc.command = ["xdg-open", url]
        openUrlProc.running = false
        openUrlProc.running = true
    }

    PanelBackground {
        id: githubBody
        anchors.fill: parent
        showBorder: false

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "github"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 90 }
                text: githubWin.myPrs.length + " open PRs"
                color: "#555555"
                font.pixelSize: 10; font.family: "monospace"
            }

            GlowButton {
                id: refreshAllBtn
                anchors { right: closeBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 60; height: 22
                cut: 4
                onClicked: githubWin.refreshAll()

                Text {
                    anchors.centerIn: parent
                    text: (githubWin.prsLoading || githubWin.reviewsLoading || githubWin.reposLoading || githubWin.notifsLoading) ? "..." : "refresh"
                    color: parent.hovered ? "#ffffff" : "#999999"
                    font.pixelSize: 9; font.family: "monospace"
                }
            }

            GlowButton {
                id: closeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 28; height: 22
                cut: 4
                accent: DivaPaint.ACCENT_RED
                onClicked: githubWin.visible = false

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: parent.hovered ? "#ffffff" : "#999999"
                    font.pixelSize: 11
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: "#2a2a2a"
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) githubWin.startSystemMove()
            }
        }

        Row {
            anchors { top: titleBar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }

            Rectangle {
                width: 150
                height: parent.height
                color: "#161616"

                Column {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }

                    component NavItem: Item {
                        id: navItem
                        property string label: ""
                        property string sym: ""
                        property string target: ""
                        property int badge: 0
                        property bool active: githubWin.section === target
                        property real activeProgress: active ? 1.0 : 0.0
                        Behavior on activeProgress { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        width: parent.width
                        height: 38

                        Item {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 2; bottomMargin: 2 }
                            clip: true

                            Canvas {
                                id: navCanvas
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
                                Connections {
                                    target: navItem
                                    function onActiveProgressChanged() { navCanvas.requestPaint() }
                                }
                                onPaint: DivaPaint.paintFacetPill(navCanvas, Math.max(navItem.activeProgress, navCanvas.hp), 6)
                            }

                            Rectangle {
                                id: navBadge
                                visible: navItem.badge > 0
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                                width: badgeText.width + 10; height: 16
                                color: navItem.active ? "#0a1a1a" : "#39c5bb"

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: navItem.badge > 99 ? "99+" : navItem.badge
                                    color: navItem.active ? "#39c5bb" : "#0a1a1a"
                                    font.pixelSize: 9; font.family: "monospace"; font.bold: true
                                }
                            }

                            Row {
                                anchors { left: parent.left; right: navBadge.visible ? navBadge.left : parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                                spacing: 10
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.sym
                                    color: navItem.active || navArea.containsMouse ? "#ffffff" : "#888888"
                                    font.pixelSize: 14
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - parent.spacing - parent.children[0].width
                                    text: navItem.label
                                    color: navItem.active || navArea.containsMouse ? "#ffffff" : "#999999"
                                    font.pixelSize: 11; font.family: "monospace"
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: navCanvas.hp = containsMouse ? 1.0 : 0.0
                                onPositionChanged: mouse => {
                                    navCanvas.mx = Math.max(0, Math.min(1, mouse.x / width))
                                    navCanvas.my = Math.max(0, Math.min(1, mouse.y / height))
                                }
                                onClicked: githubWin.section = navItem.target
                            }
                        }
                    }

                    NavItem { sym: "󰊤"; label: "my prs"; target: "pulls"; badge: githubWin.myPrs.length }
                    NavItem { sym: "󰛄"; label: "reviews"; target: "reviews"; badge: githubWin.reviewPrs.length }
                    NavItem { sym: "󰉋"; label: "repos"; target: "repos" }
                    NavItem { sym: "󰂚"; label: "notifications"; target: "notifications"; badge: githubWin.notifications.filter(function(n) { return n.unread }).length }
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height

                PullRequestsSection {
                    id: pullsSectionInstance
                    githubWin: githubWin
                    sectionActive: githubWin.section === "pulls"
                    prs: githubWin.myPrs
                    loading: githubWin.prsLoading
                    emptyText: "no open pull requests"
                }

                PullRequestsSection {
                    id: reviewsSectionInstance
                    githubWin: githubWin
                    sectionActive: githubWin.section === "reviews"
                    prs: githubWin.reviewPrs
                    loading: githubWin.reviewsLoading
                    emptyText: "no pull requests awaiting your review"
                }

                ReposSection {
                    id: reposSectionInstance
                    githubWin: githubWin
                    sectionActive: githubWin.section === "repos"
                }

                NotificationsSection {
                    id: notificationsSectionInstance
                    githubWin: githubWin
                    sectionActive: githubWin.section === "notifications"
                }
            }
        }
    }

    IpcHandler {
        target: "github"
        function toggle(): void { githubWin.visible = !githubWin.visible }
        function show(): void { githubWin.visible = true }
        function hide(): void { githubWin.visible = false }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Repos"
import "../DivaPaint.js" as DivaPaint

Window {
    id: githubWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "github"
    color: "transparent"
    width: 820
    height: 600
    visible: false

    property string mode: "github"
    property string section: "pulls"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string reposListPath: githubWin.homeDir + "/.cache/qs-repos.json"

    property var savedRepos: []
    property string activePath: ""
    property string activeRepoRoot: ""
    property var expandedRepos: ({})
    property var submoduleCache: ({})

    property string branchName: ""
    property int aheadCount: 0
    property int behindCount: 0
    property bool hasUpstream: false
    property var branchList: []
    property bool branchListLoading: false
    property bool switchingBranch: false
    property var changedFiles: []
    property var submodules: []
    property bool statusLoading: false
    property string statusError: ""

    property string selectedFile: ""
    property bool selectedStaged: false
    property string diffText: ""
    property bool diffLoading: false

    property string commitMessage: ""
    property bool committing: false
    property bool pushing: false
    property bool pulling: false
    property bool fetching: false
    property string gitOpError: ""

    function repoDisplayName(p) {
        var parts = p.split("/")
        return parts[parts.length - 1] || p
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function addRepoPath(p) {
        if (!p || p === "") return
        p = p.replace(/\/+$/, "")
        for (var i = 0; i < githubWin.savedRepos.length; i++) {
            if (githubWin.savedRepos[i].path === p) { githubWin.openRepo(p); return }
        }
        var entry = { path: p, name: githubWin.repoDisplayName(p) }
        githubWin.savedRepos = githubWin.savedRepos.concat([entry])
        githubWin.saveRepos()
        githubWin.openRepo(p)
    }

    function removeRepo(p) {
        githubWin.savedRepos = githubWin.savedRepos.filter(function(r) { return r.path !== p })
        githubWin.saveRepos()
        if (githubWin.activeRepoRoot === p || githubWin.activePath.indexOf(p) === 0) {
            githubWin.activePath = ""
            githubWin.activeRepoRoot = ""
        }
    }

    function saveRepos() {
        saveReposProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + githubWin.reposListPath + "\" <<'REPOS_EOF'\n" + JSON.stringify(githubWin.savedRepos) + "\nREPOS_EOF\n"]
        saveReposProc.running = false
        saveReposProc.running = true
    }

    function pickFolder() {
        pickFolderProc.running = false
        pickFolderProc.running = true
    }

    function openRepo(p) {
        githubWin.activePath = p
        githubWin.activeRepoRoot = p
        githubWin.selectedFile = ""
        githubWin.diffText = ""
        githubWin.commitMessage = ""
        githubWin.refreshStatus()
        githubWin.loadBranches()
    }

    function openSubmodule(parentPath, subRelPath) {
        var full = parentPath + "/" + subRelPath
        githubWin.activePath = full
        githubWin.selectedFile = ""
        githubWin.diffText = ""
        githubWin.commitMessage = ""
        githubWin.refreshStatus()
        githubWin.loadBranches()
    }

    function toggleRepoExpanded(p) {
        var m = {}
        for (var k in githubWin.expandedRepos) m[k] = githubWin.expandedRepos[k]
        m[p] = !m[p]
        githubWin.expandedRepos = m
        if (m[p] && !githubWin.submoduleCache[p]) githubWin.loadSubmodulesFor(p)
    }

    function loadSubmodulesFor(p) {
        submodulesFetchProc.pendingPath = p
        submodulesFetchProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(p) + " 2>/dev/null && git submodule status 2>/dev/null"]
        submodulesFetchProc.running = false
        submodulesFetchProc.running = true
    }

    function parseSubmoduleStatus(text) {
        var subs = []
        var subLines = text.split("\n")
        for (var j = 0; j < subLines.length; j++) {
            var sl = subLines[j]
            if (sl.trim() === "") continue
            var flag = sl[0]
            var rest = sl.substring(1).trim()
            var sp = rest.split(" ")
            var sha = sp[0]
            var subPath = sp[1]
            var branchInfo = sp.length > 2 ? sp.slice(2).join(" ") : ""
            subs.push({
                path: subPath,
                sha: sha,
                dirty: flag === "+" || flag === "-",
                notInitialized: flag === "-",
                mergeConflict: flag === "U",
                branchInfo: branchInfo.replace(/[()]/g, "")
            })
        }
        return subs
    }

    function refreshStatus() {
        if (githubWin.activePath === "") return
        githubWin.statusLoading = true
        githubWin.statusError = ""
        statusProc.command = ["bash", "-c",
            "cd " + githubWin.shellQuote(githubWin.activePath) + " 2>/dev/null && " +
            "echo ---BRANCH--- && git status --porcelain=v2 --branch && " +
            "echo ---SUBMODULES--- && git submodule status 2>/dev/null"]
        statusProc.running = false
        statusProc.running = true
    }

    function loadBranches() {
        if (githubWin.activePath === "") return
        githubWin.branchListLoading = true
        branchListProc.command = ["bash", "-c",
            "cd " + githubWin.shellQuote(githubWin.activePath) + " && git branch --format='%(HEAD) %(refname:short)'"]
        branchListProc.running = false
        branchListProc.running = true
    }

    function checkoutBranch(name) {
        if (name === githubWin.branchName) return
        githubWin.switchingBranch = true
        githubWin.gitOpError = ""
        checkoutProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git checkout " + githubWin.shellQuote(name) + " 2>&1"]
        checkoutProc.running = false
        checkoutProc.running = true
    }

    function parseStatus(text) {
        var branchSec = ""
        var subSec = ""
        var parts = text.split("---SUBMODULES---")
        var head = parts[0] || ""
        subSec = parts[1] || ""
        branchSec = head.replace("---BRANCH---", "")

        var branch = ""
        var ahead = 0, behind = 0, upstream = false
        var files = []
        var lines = branchSec.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("# branch.head ") === 0) branch = line.substring(14)
            else if (line.indexOf("# branch.upstream ") === 0) upstream = true
            else if (line.indexOf("# branch.ab ") === 0) {
                var m = line.match(/\+(\d+) -(\d+)/)
                if (m) { ahead = parseInt(m[1]); behind = parseInt(m[2]) }
            } else if (line.indexOf("1 ") === 0 || line.indexOf("2 ") === 0) {
                var fields = line.split(" ")
                var xy = fields[1]
                var path = fields[fields.length - 1]
                if (line.indexOf("2 ") === 0) {
                    var tabIdx = line.indexOf("\t")
                    if (tabIdx >= 0) path = line.substring(tabIdx + 1)
                }
                files.push({
                    path: path,
                    staged: xy[0] !== ".",
                    unstaged: xy[1] !== ".",
                    statusCode: xy,
                    isSubmodule: line.indexOf(" 160000 160000 160000 ") >= 0 || /S/.test(line.split(" ")[2] || "")
                })
            } else if (line.indexOf("u ") === 0) {
                var ufields = line.split(" ")
                files.push({ path: ufields[ufields.length - 1], staged: false, unstaged: true, statusCode: "UU", isSubmodule: false })
            } else if (line.indexOf("? ") === 0) {
                files.push({ path: line.substring(2), staged: false, unstaged: true, statusCode: "??", isSubmodule: false })
            }
        }

        var subs = githubWin.parseSubmoduleStatus(subSec)

        githubWin.branchName = branch
        githubWin.aheadCount = ahead
        githubWin.behindCount = behind
        githubWin.hasUpstream = upstream
        githubWin.changedFiles = files
        githubWin.submodules = subs
        githubWin.statusLoading = false

        if (githubWin.activePath !== "") {
            var cache = {}
            for (var ck in githubWin.submoduleCache) cache[ck] = githubWin.submoduleCache[ck]
            cache[githubWin.activePath] = subs
            githubWin.submoduleCache = cache
        }
    }

    function selectFile(f) {
        githubWin.selectedFile = f.path
        githubWin.selectedStaged = f.staged && !f.unstaged
        githubWin.diffLoading = true
        githubWin.diffText = ""
        var staged = f.staged && !f.unstaged
        var args = ["diff", "--no-color"]
        if (staged) args.push("--staged")
        if (f.statusCode === "??") {
            diffProc.command = ["bash", "-c",
                "cd " + githubWin.shellQuote(githubWin.activePath) + " && git diff --no-color --no-index /dev/null " + githubWin.shellQuote(f.path) + " 2>/dev/null || true"]
        } else {
            diffProc.command = ["bash", "-c",
                "cd " + githubWin.shellQuote(githubWin.activePath) + " && git " + args.join(" ") + " -- " + githubWin.shellQuote(f.path)]
        }
        diffProc.running = false
        diffProc.running = true
    }

    function stageFile(path) {
        gitOpProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git add -- " + githubWin.shellQuote(path)]
        gitOpProc.onDone = githubWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function unstageFile(path) {
        gitOpProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git restore --staged -- " + githubWin.shellQuote(path)]
        gitOpProc.onDone = githubWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function stageAll() {
        gitOpProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git add -A"]
        gitOpProc.onDone = githubWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function unstageAll() {
        gitOpProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git restore --staged ."]
        gitOpProc.onDone = githubWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function doCommit() {
        if (githubWin.commitMessage.trim() === "") return
        githubWin.committing = true
        var tmp = "/tmp/qs-repos-commit-msg-" + Date.now()
        commitProc.command = ["bash", "-c",
            "cd " + githubWin.shellQuote(githubWin.activePath) + " && cat > " + tmp + " <<'CM_EOF'\n" + githubWin.commitMessage + "\nCM_EOF\n" +
            "git commit -F " + tmp + "; rm -f " + tmp]
        commitProc.running = false
        commitProc.running = true
    }

    function doPush() {
        githubWin.pushing = true
        githubWin.gitOpError = ""
        pushProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git push 2>&1"]
        pushProc.running = false
        pushProc.running = true
    }

    function doPull() {
        githubWin.pulling = true
        githubWin.gitOpError = ""
        pullProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git pull 2>&1"]
        pullProc.running = false
        pullProc.running = true
    }

    function doFetch() {
        githubWin.fetching = true
        githubWin.gitOpError = ""
        fetchProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git fetch 2>&1"]
        fetchProc.running = false
        fetchProc.running = true
    }

    function updateSubmodule(subPath) {
        gitOpProc.command = ["bash", "-c", "cd " + githubWin.shellQuote(githubWin.activePath) + " && git submodule update --init --recursive -- " + githubWin.shellQuote(subPath)]
        gitOpProc.onDone = githubWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function openInTerminal(p) {
        termProc.command = ["kitty", "--directory", p]
        termProc.running = false
        termProc.running = true
    }

    function openInEditor(p) {
        editorProc.command = ["code", p]
        editorProc.running = false
        editorProc.running = true
    }

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

    property bool initialized: false

    onVisibleChanged: {
        if (visible) {
            if (!githubWin.initialized) {
                githubWin.initialized = true
                loadReposProc.running = true
            }
            refreshAll()
        }
    }

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

    Process {
        id: loadReposProc
        command: ["cat", githubWin.reposListPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    githubWin.savedRepos = Array.isArray(parsed) ? parsed : []
                } catch (_) {
                    githubWin.savedRepos = []
                }
            }
        }
    }

    Process { id: saveReposProc; command: ["true"]; running: false }

    Process {
        id: pickFolderProc
        command: ["zenity", "--file-selection", "--directory", "--title=Select a git repository"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim()
                if (p !== "") githubWin.addRepoPath(p)
            }
        }
    }

    Process {
        id: statusProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: githubWin.parseStatus(text)
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") githubWin.statusError = text.trim() }
        }
    }

    Process {
        id: submodulesFetchProc
        property string pendingPath: ""
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var subs = githubWin.parseSubmoduleStatus(text)
                var cache = {}
                for (var ck in githubWin.submoduleCache) cache[ck] = githubWin.submoduleCache[ck]
                cache[submodulesFetchProc.pendingPath] = subs
                githubWin.submoduleCache = cache
            }
        }
    }

    Process {
        id: branchListProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.branchListLoading = false
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line.trim() === "") continue
                    var isHead = line[0] === "*"
                    out.push({ name: line.substring(1).trim(), current: isHead })
                }
                githubWin.branchList = out
            }
        }
    }

    Process {
        id: checkoutProc
        command: ["true"]
        running: false
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") githubWin.gitOpError = text.trim() } }
        onExited: {
            githubWin.switchingBranch = false
            githubWin.refreshStatus()
            githubWin.loadBranches()
        }
    }

    Process {
        id: diffProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                githubWin.diffText = text
                githubWin.diffLoading = false
            }
        }
    }

    Process {
        id: gitOpProc
        property var onDone: null
        command: ["true"]
        running: false
        onExited: if (gitOpProc.onDone) gitOpProc.onDone()
    }

    Process {
        id: commitProc
        command: ["true"]
        running: false
        onExited: {
            githubWin.committing = false
            githubWin.commitMessage = ""
            githubWin.selectedFile = ""
            githubWin.diffText = ""
            githubWin.refreshStatus()
        }
    }

    Process {
        id: pushProc
        command: ["true"]
        running: false
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") githubWin.gitOpError = text.trim() } }
        onExited: { githubWin.pushing = false; githubWin.refreshStatus() }
    }

    Process {
        id: pullProc
        command: ["true"]
        running: false
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") githubWin.gitOpError = text.trim() } }
        onExited: { githubWin.pulling = false; githubWin.refreshStatus() }
    }

    Process {
        id: fetchProc
        command: ["true"]
        running: false
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") githubWin.gitOpError = text.trim() } }
        onExited: { githubWin.fetching = false; githubWin.refreshStatus() }
    }

    Process { id: termProc; command: ["true"]; running: false }
    Process { id: editorProc; command: ["true"]; running: false }

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
                text: githubWin.mode === "git" ? "git" : "github"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 90 }
                visible: githubWin.mode === "github"
                text: githubWin.myPrs.length + " open PRs"
                color: "#555555"
                font.pixelSize: 10; font.family: "monospace"
            }

            GlowButton {
                id: refreshAllBtn
                visible: githubWin.mode === "github"
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

                Row {
                    id: modeTabs
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
                    height: 26
                    spacing: 4

                    component ModeTab: Item {
                        id: modeTab
                        property string label: ""
                        property string target: ""
                        readonly property bool active: githubWin.mode === target
                        width: (modeTabs.width - modeTabs.spacing) / 2
                        height: parent.height

                        Canvas {
                            id: modeTabCanvas
                            anchors.fill: parent
                            property real hp: 0.0
                            Behavior on hp { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            onHpChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            Connections {
                                target: modeTab
                                function onActiveChanged() { modeTabCanvas.requestPaint() }
                            }
                            onPaint: DivaPaint.paintFacetPill(modeTabCanvas, Math.max(hp, modeTab.active ? 1.0 : 0.0), 4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modeTab.label
                            color: modeTab.active ? "#ffffff" : "#999999"
                            font.pixelSize: 10; font.family: "monospace"; font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: modeTabCanvas.hp = containsMouse ? 1.0 : 0.0
                            onClicked: githubWin.mode = modeTab.target
                        }
                    }

                    ModeTab { label: "github"; target: "github" }
                    ModeTab { label: "git"; target: "git" }
                }

                Column {
                    visible: githubWin.mode === "github"
                    anchors { top: modeTabs.bottom; left: parent.left; right: parent.right; topMargin: 8 }

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

                RepoSidebar {
                    visible: githubWin.mode === "git"
                    anchors { top: modeTabs.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 6 }
                    reposWin: githubWin
                }
            }

            Item {
                width: parent.width - 150
                height: parent.height
                visible: githubWin.mode === "github"

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

            Item {
                width: parent.width - 150
                height: parent.height
                visible: githubWin.mode === "git"

                RepoWorkspace {
                    anchors.fill: parent
                    reposWin: githubWin
                    visible: githubWin.activePath !== ""
                }

                Column {
                    anchors.centerIn: parent
                    visible: githubWin.activePath === ""
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰊢"
                        color: "#333333"
                        font.pixelSize: 40
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "select or add a repository"
                        color: "#555555"
                        font.pixelSize: 12; font.family: "monospace"
                    }
                }
            }
        }
    }

}

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../DivaPaint.js" as DivaPaint

Window {
    id: reposWin
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    title: "repos"
    color: "transparent"
    width: 1040
    height: 680
    visible: false

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string reposListPath: reposWin.homeDir + "/.cache/qs-repos.json"

    // list of { path, name } main repos added by the user
    property var savedRepos: []

    // navigation: which git root are we currently viewing (main repo or a submodule path)
    property string activePath: ""
    property string activeRepoRoot: ""

    // git status of activePath
    property string branchName: ""
    property int aheadCount: 0
    property int behindCount: 0
    property bool hasUpstream: false
    property var changedFiles: []
    property var submodules: []
    property bool statusLoading: false
    property string statusError: ""

    // selected file + diff
    property string selectedFile: ""
    property bool selectedStaged: false
    property string diffText: ""
    property bool diffLoading: false

    property string commitMessage: ""
    property bool committing: false
    property bool pushing: false
    property bool pulling: false
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
        for (var i = 0; i < reposWin.savedRepos.length; i++) {
            if (reposWin.savedRepos[i].path === p) { reposWin.openRepo(p); return }
        }
        var entry = { path: p, name: reposWin.repoDisplayName(p) }
        reposWin.savedRepos = reposWin.savedRepos.concat([entry])
        reposWin.saveRepos()
        reposWin.openRepo(p)
    }

    function removeRepo(p) {
        reposWin.savedRepos = reposWin.savedRepos.filter(function(r) { return r.path !== p })
        reposWin.saveRepos()
        if (reposWin.activeRepoRoot === p || reposWin.activePath.indexOf(p) === 0) {
            reposWin.activePath = ""
            reposWin.activeRepoRoot = ""
        }
    }

    function saveRepos() {
        saveReposProc.command = ["bash", "-c", "mkdir -p ~/.cache && cat > \"" + reposWin.reposListPath + "\" <<'REPOS_EOF'\n" + JSON.stringify(reposWin.savedRepos) + "\nREPOS_EOF\n"]
        saveReposProc.running = false
        saveReposProc.running = true
    }

    function pickFolder() {
        pickFolderProc.running = false
        pickFolderProc.running = true
    }

    function openRepo(p) {
        reposWin.activePath = p
        reposWin.activeRepoRoot = p
        reposWin.selectedFile = ""
        reposWin.diffText = ""
        reposWin.commitMessage = ""
        reposWin.refreshStatus()
    }

    function openSubmodule(parentPath, subRelPath) {
        var full = parentPath + "/" + subRelPath
        reposWin.activePath = full
        reposWin.selectedFile = ""
        reposWin.diffText = ""
        reposWin.commitMessage = ""
        reposWin.refreshStatus()
    }

    function refreshStatus() {
        if (reposWin.activePath === "") return
        reposWin.statusLoading = true
        reposWin.statusError = ""
        statusProc.command = ["bash", "-c",
            "cd " + reposWin.shellQuote(reposWin.activePath) + " 2>/dev/null && " +
            "echo ---BRANCH--- && git status --porcelain=v2 --branch && " +
            "echo ---SUBMODULES--- && git submodule status 2>/dev/null"]
        statusProc.running = false
        statusProc.running = true
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
                    // renames have an extra "orig -> " path segment appended after a tab in some formats; porcelain v2 puts orig path at the very end preceded by original relative path with a tab
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

        var subs = []
        var subLines = subSec.split("\n")
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

        reposWin.branchName = branch
        reposWin.aheadCount = ahead
        reposWin.behindCount = behind
        reposWin.hasUpstream = upstream
        reposWin.changedFiles = files
        reposWin.submodules = subs
        reposWin.statusLoading = false
    }

    function selectFile(f) {
        reposWin.selectedFile = f.path
        reposWin.selectedStaged = f.staged && !f.unstaged
        reposWin.diffLoading = true
        reposWin.diffText = ""
        var staged = f.staged && !f.unstaged
        var args = ["diff", "--no-color"]
        if (staged) args.push("--staged")
        if (f.statusCode === "??") {
            diffProc.command = ["bash", "-c",
                "cd " + reposWin.shellQuote(reposWin.activePath) + " && git diff --no-color --no-index /dev/null " + reposWin.shellQuote(f.path) + " 2>/dev/null || true"]
        } else {
            diffProc.command = ["bash", "-c",
                "cd " + reposWin.shellQuote(reposWin.activePath) + " && git " + args.join(" ") + " -- " + reposWin.shellQuote(f.path)]
        }
        diffProc.running = false
        diffProc.running = true
    }

    function stageFile(path) {
        gitOpProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git add -- " + reposWin.shellQuote(path)]
        gitOpProc.onDone = reposWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function unstageFile(path) {
        gitOpProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git restore --staged -- " + reposWin.shellQuote(path)]
        gitOpProc.onDone = reposWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function stageAll() {
        gitOpProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git add -A"]
        gitOpProc.onDone = reposWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function unstageAll() {
        gitOpProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git restore --staged ."]
        gitOpProc.onDone = reposWin.refreshStatus
        gitOpProc.running = false
        gitOpProc.running = true
    }

    function doCommit() {
        if (reposWin.commitMessage.trim() === "") return
        reposWin.committing = true
        var tmp = "/tmp/qs-repos-commit-msg-" + Date.now()
        commitProc.command = ["bash", "-c",
            "cd " + reposWin.shellQuote(reposWin.activePath) + " && cat > " + tmp + " <<'CM_EOF'\n" + reposWin.commitMessage + "\nCM_EOF\n" +
            "git commit -F " + tmp + "; rm -f " + tmp]
        commitProc.running = false
        commitProc.running = true
    }

    function doPush() {
        reposWin.pushing = true
        reposWin.gitOpError = ""
        pushProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git push 2>&1"]
        pushProc.running = false
        pushProc.running = true
    }

    function doPull() {
        reposWin.pulling = true
        reposWin.gitOpError = ""
        pullProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git pull 2>&1"]
        pullProc.running = false
        pullProc.running = true
    }

    function updateSubmodule(subPath) {
        gitOpProc.command = ["bash", "-c", "cd " + reposWin.shellQuote(reposWin.activePath) + " && git submodule update --init --recursive -- " + reposWin.shellQuote(subPath)]
        gitOpProc.onDone = reposWin.refreshStatus
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

    Component.onCompleted: loadReposProc.running = true

    onVisibleChanged: if (visible && reposWin.activePath !== "") reposWin.refreshStatus()

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: if (reposWin.visible && reposWin.activePath !== "") reposWin.refreshStatus()
    }

    Process {
        id: loadReposProc
        command: ["cat", reposWin.reposListPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    reposWin.savedRepos = Array.isArray(parsed) ? parsed : []
                } catch (_) {
                    reposWin.savedRepos = []
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
                if (p !== "") reposWin.addRepoPath(p)
            }
        }
    }

    Process {
        id: statusProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: reposWin.parseStatus(text)
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") reposWin.statusError = text.trim() }
        }
    }

    Process {
        id: diffProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                reposWin.diffText = text
                reposWin.diffLoading = false
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
            reposWin.committing = false
            reposWin.commitMessage = ""
            reposWin.selectedFile = ""
            reposWin.diffText = ""
            reposWin.refreshStatus()
        }
    }

    Process {
        id: pushProc
        command: ["true"]
        running: false
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") reposWin.gitOpError = text.trim() } }
        onExited: { reposWin.pushing = false; reposWin.refreshStatus() }
    }

    Process {
        id: pullProc
        command: ["true"]
        running: false
        stderr: StdioCollector { onStreamFinished: { if (text.trim() !== "") reposWin.gitOpError = text.trim() } }
        onExited: { reposWin.pulling = false; reposWin.refreshStatus() }
    }

    Process { id: termProc; command: ["true"]; running: false }
    Process { id: editorProc; command: ["true"]; running: false }

    PanelBackground {
        id: reposBody
        anchors.fill: parent
        showBorder: false

        Item {
            id: titleBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 38

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                text: "repos"
                color: "#39c5bb"
                font.pixelSize: 11; font.family: "Orbitron"
            }

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 70 }
                visible: reposWin.activePath !== ""
                text: reposWin.activePath
                color: "#555555"
                font.pixelSize: 10; font.family: "monospace"
                elide: Text.ElideMiddle
                width: 400
            }

            GlowButton {
                id: closeBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                width: 28; height: 22
                cut: 4
                accent: DivaPaint.ACCENT_RED
                onClicked: reposWin.visible = false

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
                onActiveChanged: if (active) reposWin.startSystemMove()
            }
        }

        Row {
            anchors { top: titleBar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }

            RepoSidebar {
                id: sidebar
                reposWin: reposWin
                width: 220
                height: parent.height
            }

            Item {
                width: parent.width - sidebar.width
                height: parent.height

                RepoWorkspace {
                    anchors.fill: parent
                    reposWin: reposWin
                    visible: reposWin.activePath !== ""
                }

                Column {
                    anchors.centerIn: parent
                    visible: reposWin.activePath === ""
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

    IpcHandler {
        target: "repos"
        function toggle(): void { reposWin.visible = !reposWin.visible }
        function show(): void { reposWin.visible = true }
        function hide(): void { reposWin.visible = false }
    }
}

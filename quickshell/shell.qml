//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./bar"
import "./bar/Kanade"
import "./bar/GitHub"
import "./bar/Repos"

ShellRoot {
    Bar {}
    AppLauncher {}
    LockWin {}
    KeybindsPopup {}
    Kanade {}
    GitHub {}
    Repos {}
}

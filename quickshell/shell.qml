//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./bar"
import "./bar/Kanade"
import "./bar/GitHub"

ShellRoot {
    Bar {}
    AppLauncher {}
    LockWin {}
    KeybindsPopup {}
    Kanade {}
    GitHub {}
}

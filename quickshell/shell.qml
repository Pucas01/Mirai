//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./bar"
import "./bar/Kanade"

ShellRoot {
    Bar {}
    AppLauncher {}
    LockWin {}
    KeybindsPopup {}
    Kanade {}
}

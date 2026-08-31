//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "./bar"
import "./bar/Kanade"
import "./bar/GitHub"

ShellRoot {
    Bar {}
    AppLauncher {}
    LockWin {}
    KeybindsPopup {}

    LazyLoader {
        id: kanadeLoader
        Kanade {}
    }

    LazyLoader {
        id: githubLoader
        GitHub {}
    }

    LazyLoader {
        id: wallpaperLoader
        WallpaperSwitcher {}
    }

    IpcHandler {
        target: "kanade"
        function toggle(): void {
            kanadeLoader.active = true
            kanadeLoader.item.visible = !kanadeLoader.item.visible
        }
        function show(): void {
            kanadeLoader.active = true
            kanadeLoader.item.visible = true
        }
        function hide(): void {
            if (kanadeLoader.active) kanadeLoader.item.visible = false
        }
    }

    IpcHandler {
        target: "github"
        function toggle(): void {
            githubLoader.active = true
            githubLoader.item.visible = !githubLoader.item.visible
        }
        function show(): void {
            githubLoader.active = true
            githubLoader.item.visible = true
        }
        function hide(): void {
            if (githubLoader.active) githubLoader.item.visible = false
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            wallpaperLoader.active = true
            if (wallpaperLoader.item.visible) wallpaperLoader.item.closeSwitcher()
            else wallpaperLoader.item.open()
        }
        function show(): void {
            wallpaperLoader.active = true
            wallpaperLoader.item.open()
        }
        function hide(): void {
            if (wallpaperLoader.active) wallpaperLoader.item.closeSwitcher()
        }
    }
}

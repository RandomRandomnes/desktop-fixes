import qs
import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia
import com.github.catsout.wallpaperEngineKde 1.2

// Draws a Wallpaper Engine wallpaper (scene or video) inside the background surface, under the desktop widgets
// (2026-10-03). Scenes use the renderer from the KDE plugin package (AUR wallpaper-engine-kde-plugin-git).
// Background.qml loads this file through a Loader, so if that package is missing only this layer fails.
// `wallpaper` comes from GlobalStates.wallpaperEngineInShell: {dir, volume, silent, fps, scaling}.
Item {
    id: root
    property var wallpaper: ({})
    property bool paused: false

    property var project: ({})
    readonly property string type: (project.type ?? "").toLowerCase()
    readonly property string fileUrl: project.file && wallpaper.dir ? `file://${wallpaper.dir}/${project.file}` : ""
    // Wallpaper Engine's own assets sit in the same Steam library as the wallpaper (…/steamapps/workshop/content/
    // 431960/<id> -> …/steamapps/common/wallpaper_engine/assets), also when that library is on another drive (F26)
    readonly property string assetsDir: {
        const i = (wallpaper.dir ?? "").indexOf("/steamapps/workshop/")
        return i >= 0 ? `${wallpaper.dir.substring(0, i)}/steamapps/common/wallpaper_engine/assets`
                      : `${Quickshell.env("HOME")}/.local/share/Steam/steamapps/common/wallpaper_engine/assets`
    }
    readonly property real volume: wallpaper.silent ? 0 : Math.max(0, Math.min(100, wallpaper.volume ?? 100))
    // The app's per-wallpaper settings (--set-property, strings) typed using project.json general.properties,
    // as the scene renderer's override JSON {name: value}. Empty string = project defaults.
    readonly property string userPropsJson: {
        const set = wallpaper.props ?? {};
        const defs = project.general?.properties ?? {};
        const out = {};
        for (const name in set) {
            const raw = set[name], def = defs[name];
            if (!def) continue;
            switch (def.type) {
                case "bool": out[name] = raw === "true" || raw === "1"; break;
                case "slider": out[name] = Number(raw); break;
                case "combo": {
                    const opt = (def.options ?? []).find(o => String(o.value) === raw);
                    out[name] = opt ? opt.value : raw;
                    break;
                }
                default: out[name] = raw;  // color ("r g b"), textinput, file, ...
            }
        }
        return Object.keys(out).length > 0 ? JSON.stringify(out) : "";
    }

    FileView {
        path: root.wallpaper.dir ? `${root.wallpaper.dir}/project.json` : ""
        onLoaded: {
            try { root.project = JSON.parse(text()) } catch (e) { root.project = {} }
        }
        onLoadFailed: root.project = {}
    }

    Loader {
        anchors.fill: parent
        active: root.fileUrl !== ""
        sourceComponent: root.type === "scene" ? sceneComponent : root.type === "video" ? videoComponent : null
    }

    Component {
        id: sceneComponent
        SceneViewer {
            id: scene
            assets: `file://${root.assetsDir}`
            source: root.fileUrl
            fps: root.wallpaper.fps || 60
            volume: root.volume / 100
            muted: root.volume === 0
            userProperties: root.userPropsJson
            fillMode: root.wallpaper.scaling === "stretch" ? SceneViewer.STRETCH
                : root.wallpaper.scaling === "fit" ? SceneViewer.ASPECTFIT : SceneViewer.ASPECTCROP
            Component.onCompleted: {
                scene.setAcceptHover(true)  // mouse parallax; clicks stay with the desktop
                if (!root.paused) scene.play()
            }
            Connections {
                target: root
                function onPausedChanged() { root.paused ? scene.pause() : scene.play() }
            }
        }
    }

    // Videos use Qt Multimedia instead of the plugin's mpv player: that one always adds a CPU vflip filter and cannot
    // do zero-copy hardware decoding here (vulkan-copy / software, ~100-136% CPU on a 4K60 video).
    Component {
        id: videoComponent
        Item {
            MediaPlayer {
                id: player
                source: root.fileUrl
                loops: MediaPlayer.Infinite
                videoOutput: output
                audioOutput: AudioOutput {
                    muted: root.volume === 0 || GlobalStates.wallpaperEngineMuted
                    volume: root.volume / 100
                }
                Component.onCompleted: if (!root.paused) player.play()
            }
            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: root.wallpaper.scaling === "stretch" ? VideoOutput.Stretch
                    : root.wallpaper.scaling === "fit" ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
            }
            Connections {
                target: root
                function onPausedChanged() { root.paused ? player.pause() : player.play() }
            }
        }
    }
}

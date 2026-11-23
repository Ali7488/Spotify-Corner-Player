import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as Plasma5Support
import "ThemeColors.js" as ThemeColors

PlasmoidItem {
    id: root

    // KConfig persists settings for this particular instance of the widget.
    readonly property string themeId: Plasmoid.configuration.themeId || "Forest"
    readonly property string playerPreference: Plasmoid.configuration.playerPreference || "Auto"

    // Native KDE Plasma 6 popup pinning, Linux only.
    hideOnWindowDeactivate: !pinned
    readonly property bool compactMode: Plasmoid.configuration.compactMode ?? false
    readonly property bool pinned: Plasmoid.configuration.pinned ?? false
    readonly property string artworkMode: Plasmoid.configuration.artworkMode === "Artwork" ? "Artwork" : "Vinyl"

    function toggleArtworkMode() {
        Plasmoid.configuration.artworkMode = artworkMode === "Vinyl" ? "Artwork" : "Vinyl";
    }

    function toggleCompactMode() {
        Plasmoid.configuration.compactMode = !compactMode;
    }
    function togglePinned() {
        Plasmoid.configuration.pinned = !pinned;
        if (Plasmoid.configuration.pinned)
            expanded = true;
    }

    property var player: null
    property var players: []
    property string activeSource: ""
    property bool launchingPlayer: false
    property string launchError: ""

    readonly property string track: player?.track ?? ""
    readonly property string artist: player?.artist ?? ""
    readonly property string album: player?.album ?? ""
    readonly property string artwork: player?.artUrl ?? ""
    readonly property real duration: player?.length ?? 0
    readonly property bool playing: player?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string sourceLabel: activeSource || (playerPreference === "Auto"
                                                         ? "Spotify / Spotifast" : playerPreference)
    readonly property string launchTarget: playerPreference !== "Auto"
                                           ? playerPreference : activeSource
    readonly property bool spotifyRunning: players.some(probe => sourceKey(probe) === "Spotify")
    readonly property bool spotifastRunning: players.some(probe => sourceKey(probe) === "Spotifast")
    // KDE libkmpris exposes MPRIS repeat and normalized player volume.
    readonly property int loopStatus: player?.loopStatus ?? -1
    readonly property bool repeatAvailable: Boolean(player?.canControl)
        && (loopStatus === Mpris.LoopStatus.None
            || loopStatus === Mpris.LoopStatus.Playlist
            || loopStatus === Mpris.LoopStatus.Track)
    readonly property string repeatLabel: loopStatus === Mpris.LoopStatus.Playlist
        ? "Repeat all" : loopStatus === Mpris.LoopStatus.Track
            ? "Repeat one" : "Repeat off"
    readonly property real playerVolume: player?.volume ?? NaN
    readonly property bool volumeAvailable: Boolean(player?.canControl)
        && Number.isFinite(playerVolume) && playerVolume >= 0 && playerVolume <= 1
    function cycleRepeat() {
        if (!repeatAvailable) return;
        player.loopStatus = loopStatus === Mpris.LoopStatus.None
            ? Mpris.LoopStatus.Playlist
            : loopStatus === Mpris.LoopStatus.Playlist
                ? Mpris.LoopStatus.Track : Mpris.LoopStatus.None;
    }
    function setPlayerVolume(value) {
        if (!volumeAvailable || !Number.isFinite(value)) return;
        player.volume = Math.max(0, Math.min(1, value));
    }

    readonly property int shuffleStatus: player?.shuffle ?? Mpris.ShuffleStatus.Unknown
    readonly property bool shuffleOn: shuffleStatus === Mpris.ShuffleStatus.On
    readonly property bool shuffleAvailable: (player?.canControl ?? false)
        && (shuffleStatus === Mpris.ShuffleStatus.On || shuffleStatus === Mpris.ShuffleStatus.Off)

    function setTheme(id) {
        if (["Burgundy", "Forest", "Sapphire", "Amethyst", "Obsidian"].indexOf(id) !== -1)
            Plasmoid.configuration.themeId = id;
    }

    function setPlayerPreference(id) {
        if (["Auto", "Spotify", "Spotifast"].indexOf(id) === -1)
            return;
        Plasmoid.configuration.playerPreference = id;
        Qt.callLater(choosePlayer);
    }

    function sourceKey(probe) {
        const identity = String(probe?.identity ?? "").toLowerCase();
        const entry = String(probe?.desktopEntry ?? "").toLowerCase();
        if (/(^|[^a-z0-9])spotifast([^a-z0-9]|$)/.test(identity + " " + entry))
            return "Spotifast";
        if (/(^|[^a-z0-9])spotify([^a-z0-9]|$)/.test(identity + " " + entry)
                || /com\.spotify\.client/.test(entry))
            return "Spotify";
        return "";
    }

    function choosePlayer() {
        const matches = players.filter(probe => sourceKey(probe) !== "");
        const preferred = playerPreference === "Auto"
            ? matches
            : matches.filter(probe => sourceKey(probe) === playerPreference);
        // Auto follows active playback, then prefers the existing Spotifast
        // session as it did in Emerald Vinyl. Unrelated MPRIS apps are ignored.
        const chosen = preferred.find(probe => probe.container?.playbackStatus === Mpris.PlaybackStatus.Playing)
            ?? preferred.find(probe => sourceKey(probe) === "Spotifast")
            ?? preferred[0] ?? null;
        player = chosen?.container ?? null;
        activeSource = chosen ? sourceKey(chosen) : "";
    }

    function toggleShuffle() {
        if (shuffleAvailable)
            player.shuffle = shuffleOn ? Mpris.ShuffleStatus.Off : Mpris.ShuffleStatus.On;
    }

    function openSelectedPlayer() {
        launchError = "";
        if (player?.canRaise && typeof player.Raise === "function") {
            player.Raise();
            return;
        }
        if (!launchTarget) {
            launchError = "Choose Spotify or Spotifast from the player menu first.";
            return;
        }
        if (!launchingPlayer) {
            launchingPlayer = true;
            playerLauncher.connectSource(launchTarget === "Spotify"
                                        ? playerLauncher.spotifyCommand
                                        : playerLauncher.spotifastCommand);
        }
    }

    Plasma5Support.DataSource {
        id: playerLauncher
        engine: "executable"
        connectedSources: []
        // These commands are fixed strings, never built from track metadata.
        // They use desktop entries first and native / Flatpak / Snap fallbacks.
        readonly property string spotifyCommand: "sh -c '"
            + "for launcher in kstart6 kstart; do "
            + "if command -v \"$launcher\" >/dev/null 2>&1; then "
            + "\"$launcher\" --application spotify && exit 0; "
            + "\"$launcher\" --application com.spotify.Client && exit 0; fi; done; "
            + "if command -v spotify >/dev/null 2>&1; then setsid -f spotify; "
            + "elif command -v flatpak >/dev/null 2>&1 && flatpak info com.spotify.Client >/dev/null 2>&1; then "
            + "setsid -f flatpak run com.spotify.Client; "
            + "elif command -v snap >/dev/null 2>&1 && snap list spotify >/dev/null 2>&1; then "
            + "setsid -f snap run spotify; else exit 127; fi'"
        readonly property string spotifastCommand: "sh -c '"
            + "for launcher in kstart6 kstart; do "
            + "if command -v \"$launcher\" >/dev/null 2>&1; then "
            + "\"$launcher\" --application spotifast && exit 0; "
            + "\"$launcher\" --application rocks.spotifast.Spotifast && exit 0; fi; done; "
            + "if command -v spotifast >/dev/null 2>&1; then setsid -f spotifast; "
            + "elif command -v flatpak >/dev/null 2>&1 && flatpak info rocks.spotifast.Spotifast >/dev/null 2>&1; then "
            + "setsid -f flatpak run rocks.spotifast.Spotifast; else exit 127; fi'"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.launchingPlayer = false;
            if (data["exit code"] !== 0)
                root.launchError = "Unable to start the selected player. Check that it is installed.";
        }
    }

    Mpris.Mpris2Model { id: media }
    Instantiator {
        model: media
        delegate: Item {
            required property var container
            required property string identity
            required property string desktopEntry
            onIdentityChanged: Qt.callLater(root.choosePlayer)
            onDesktopEntryChanged: Qt.callLater(root.choosePlayer)
            onContainerChanged: Qt.callLater(root.choosePlayer)
            Connections {
                target: container
                ignoreUnknownSignals: true
                function onPlaybackStatusChanged() { Qt.callLater(root.choosePlayer); }
            }
        }
        onObjectAdded: (index, object) => {
            root.players = [...root.players, object];
            Qt.callLater(root.choosePlayer);
        }
        onObjectRemoved: (index, object) => {
            root.players = root.players.filter(probe => probe !== object);
            Qt.callLater(root.choosePlayer);
        }
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "media-optical-audio"
    toolTipMainText: track || "Corner Media Player"
    toolTipSubText: artist || sourceLabel
    toolTipTextFormat: Text.PlainText

    compactRepresentation: QQC.AbstractButton {
        Layout.minimumWidth: 26
        Layout.minimumHeight: 26
        implicitWidth: 34
        implicitHeight: 34
        Accessible.name: "Open Corner Media Player"
        onClicked: root.expanded = !root.expanded
        background: Rectangle {
            radius: width / 2
            color: parent.hovered ? ThemeColors.get(root.themeId).hover : "transparent"
        }
        contentItem: Kirigami.Icon {
            source: "media-optical-audio"
            active: root.playing
        }
    }
    fullRepresentation: Loader {
        // Compact actually reduces popup geometry, not just the artwork.
        Layout.minimumWidth: compactMode ? 240 : 400
        Layout.preferredWidth: compactMode ? 276 : 432
        Layout.minimumHeight: compactMode ? 96 : 480
        Layout.preferredHeight: compactMode ? 104 : 500
        active: root.expanded
        sourceComponent: VinylPopup { media: root }
    }
}

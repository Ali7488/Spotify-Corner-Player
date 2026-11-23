import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC
import "ThemeColors.js" as ThemeColors

Rectangle {
    id: popup
    required property var media
    readonly property var palette: ThemeColors.get(media.themeId)
    color: palette.background
    radius: 20
    border.color: palette.border

    readonly property color cream: palette.text
    readonly property color muted: palette.muted
    readonly property color coral: palette.accent
    readonly property color forest: palette.surface
    readonly property color line: palette.border
    readonly property var transportPaths: ({
        "media-skip-backward": "M 5 4 H 9 V 24 H 5 Z M 23 4 L 9 14 L 23 24 Z",
        "media-playback-start": "M 7 4 L 23 14 L 7 24 Z",
        "media-playback-pause": "M 7 4 H 12 V 24 H 7 Z M 16 4 H 21 V 24 H 16 Z",
        "media-skip-forward": "M 19 4 H 23 V 24 H 19 Z M 5 4 L 19 14 L 5 24 Z"
    })
    readonly property string lyricsUrl: media.track.trim()
        ? "https://www.google.com/search?q=" + encodeURIComponent([media.track.trim(), media.artist.trim(), "lyrics"].filter(Boolean).join(" "))
        : ""
    readonly property real position: media.player?.position ?? 0
    property string lyricsError: ""

    function timeText(us) {
        const seconds = Math.max(0, Math.floor(us / 1000000));
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }

    onLyricsUrlChanged: lyricsError = ""
    Timer {
        interval: 800
        repeat: true
        running: popup.visible && media.playing
        onTriggered: media.player?.updatePosition()
    }

    component PlayerButton: QQC.Button {
        id: button
        property string symbol: ""
        property bool accent: false
        property bool small: false
        hoverEnabled: true
        opacity: enabled ? 1 : 0.48
        background: Rectangle {
            radius: button.height < 40 ? 10 : 14
            color: button.accent
                ? (button.down ? popup.palette.accent : button.hovered ? popup.palette.accentHover : popup.coral)
                : (button.down ? popup.palette.pressed : button.hovered ? popup.palette.hover : popup.palette.button)
            border.width: button.visualFocus ? 2 : 1
            border.color: button.accent || button.visualFocus ? popup.coral : popup.line
        }
        contentItem: Item {
            implicitWidth: button.symbol ? 30 : caption.implicitWidth
            implicitHeight: button.symbol ? 30 : caption.implicitHeight
            Shape {
                anchors.centerIn: parent
                width: 28
                height: 28
                visible: Boolean(button.symbol)
                ShapePath {
                    strokeWidth: -1
                    fillColor: button.accent ? popup.palette.onAccent : popup.cream
                    PathSvg { path: popup.transportPaths[button.symbol] ?? "" }
                }
            }
            Text {
                id: caption
                anchors.centerIn: parent
                visible: !button.symbol
                text: button.text
                textFormat: Text.PlainText
                color: button.accent ? popup.palette.onAccent : popup.cream
                font.pixelSize: button.small ? 10 : 13
                font.weight: Font.DemiBold
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: media.compactMode ? 14 : 20
        spacing: media.compactMode ? 7 : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle { width: 8; height: 8; radius: 4; color: popup.coral }
            ColumnLayout {
                spacing: 2
                QQC.Label {
                    text: media.sourceLabel.toUpperCase()
                    color: popup.cream
                    font.pixelSize: 14
                    font.bold: true
                }
                QQC.Label {
                    text: "Now playing"
                    color: popup.muted
                    font.pixelSize: 12
                }
            }
            Item { Layout.fillWidth: true }
            // Preferences are native Plasma menus, not terminal commands.
            QQC.Button {
                id: sourceButton
                objectName: "sourceButton"
                Layout.preferredWidth: 34
                Layout.preferredHeight: 32
                text: "♫"
                Accessible.name: "Choose Spotify or Spotifast"
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: "Playback source"
                background: Rectangle {
                    radius: 9
                    color: sourceButton.hovered ? popup.palette.hover : popup.palette.button
                    border.color: popup.palette.border
                }
                contentItem: Text {
                    text: sourceButton.text
                    color: popup.palette.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 18
                }
                onClicked: sourceMenu.open()
                QQC.Menu {
                    id: sourceMenu
                    y: sourceButton.height
                    background: Rectangle {
                        radius: 11
                        color: popup.palette.surface
                        border.color: popup.palette.border
                    }
                    QQC.MenuItem {
                        text: "Auto (active player)"
                        checkable: true
                        checked: media.playerPreference === "Auto"
                        onClicked: media.setPlayerPreference("Auto")
                    }
                    QQC.MenuItem {
                        text: media.spotifyRunning ? "Spotify (running)" : "Spotify (not running)"
                        checkable: true
                        checked: media.playerPreference === "Spotify"
                        onClicked: media.setPlayerPreference("Spotify")
                    }
                    QQC.MenuItem {
                        text: media.spotifastRunning ? "Spotifast (running)" : "Spotifast (not running)"
                        checkable: true
                        checked: media.playerPreference === "Spotifast"
                        onClicked: media.setPlayerPreference("Spotifast")
                    }
                }
            }
            QQC.Button {
                id: themeButton
                objectName: "themeButton"
                Layout.preferredWidth: 34
                Layout.preferredHeight: 32
                text: "◐"
                Accessible.name: "Choose color theme"
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: "Color theme"
                background: Rectangle {
                    radius: 9
                    color: themeButton.hovered ? popup.palette.hover : popup.palette.button
                    border.color: popup.palette.border
                }
                contentItem: Text {
                    text: themeButton.text
                    color: popup.palette.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 19
                }
                onClicked: themeMenu.open()
                QQC.Menu {
                    id: themeMenu
                    y: themeButton.height
                    background: Rectangle {
                        radius: 11
                        color: popup.palette.surface
                        border.color: popup.palette.border
                    }
                    QQC.MenuItem {
                        text: ThemeColors.label("Burgundy")
                        checkable: true
                        checked: media.themeId === "Burgundy"
                        onClicked: media.setTheme("Burgundy")
                        contentItem: Row {
                            spacing: 7
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Burgundy").primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Burgundy").accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ThemeColors.label("Burgundy")
                                color: popup.palette.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    QQC.MenuItem {
                        text: ThemeColors.label("Forest")
                        checkable: true
                        checked: media.themeId === "Forest"
                        onClicked: media.setTheme("Forest")
                        contentItem: Row {
                            spacing: 7
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Forest").primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Forest").accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ThemeColors.label("Forest")
                                color: popup.palette.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    QQC.MenuItem {
                        text: ThemeColors.label("Sapphire")
                        checkable: true
                        checked: media.themeId === "Sapphire"
                        onClicked: media.setTheme("Sapphire")
                        contentItem: Row {
                            spacing: 7
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Sapphire").primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Sapphire").accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ThemeColors.label("Sapphire")
                                color: popup.palette.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    QQC.MenuItem {
                        text: ThemeColors.label("Amethyst")
                        checkable: true
                        checked: media.themeId === "Amethyst"
                        onClicked: media.setTheme("Amethyst")
                        contentItem: Row {
                            spacing: 7
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Amethyst").primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Amethyst").accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ThemeColors.label("Amethyst")
                                color: popup.palette.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    QQC.MenuItem {
                        text: ThemeColors.label("Obsidian")
                        checkable: true
                        checked: media.themeId === "Obsidian"
                        onClicked: media.setTheme("Obsidian")
                        contentItem: Row {
                            spacing: 7
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Obsidian").primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: ThemeColors.get("Obsidian").accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ThemeColors.label("Obsidian")
                                color: popup.palette.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            PlayerButton {
                objectName: "shuffleButton"
                Layout.preferredWidth: 66
                Layout.preferredHeight: 26
                small: true
                text: media.shuffleOn ? "Shuffle ✓" : "Shuffle"
                Accessible.name: media.shuffleOn ? "Disable shuffle" : "Enable shuffle"
                enabled: media.shuffleAvailable
                accent: media.shuffleOn
                onClicked: media.toggleShuffle()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 27
            spacing: 5
            PlayerButton {
                objectName: "compactButton"
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                small: true
                text: media.compactMode ? "Expand" : "Compact"
                Accessible.name: media.compactMode ? "Expanded view" : "Compact view"
                onClicked: media.toggleCompactMode()
            }
            PlayerButton {
                objectName: "pinButton"
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                small: true
                accent: media.pinned
                text: media.pinned ? "Unpin" : "Pin"
                Accessible.name: media.pinned ? "Unpin player" : "Pin player open"
                onClicked: media.togglePinned()
            }
            PlayerButton {
                objectName: "repeatButton"
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                small: true
                text: media.repeatAvailable ? (media.loopStatus === 2 ? "Repeat 1" : media.loopStatus === 1 ? "Repeat all" : "Repeat") : "Repeat"
                Accessible.name: media.repeatLabel
                enabled: media.repeatAvailable
                onClicked: media.cycleRepeat()
            }
            PlayerButton {
                objectName: "artworkButton"
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                small: true
                text: media.artworkMode === "Vinyl" ? "Vinyl" : "Artwork"
                Accessible.name: "Switch between original artwork and spinning vinyl"
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: "Display: " + media.artworkMode + ". Click to switch."
                onClicked: media.toggleArtworkMode()
            }
        }

        // Compact mode keeps title, artist, progress, and transport accessible.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: media.compactMode ? 48 : 0
            visible: media.compactMode
            spacing: 2
            QQC.Label {
                Layout.fillWidth: true
                text: media.track || "No track playing"
                textFormat: Text.PlainText
                color: popup.cream
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
            }
            QQC.Label {
                Layout.fillWidth: true
                text: media.artist || media.sourceLabel
                textFormat: Text.PlainText
                color: popup.muted
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: !media.compactMode
            Layout.minimumHeight: media.compactMode ? 0 : 148
            visible: !media.compactMode
            spacing: 19

            Item {
                Layout.preferredWidth: 176
                Layout.fillHeight: true
                clip: true
                Item {
                    id: recordStage
                    property real platterAngle: 0
                    property real spinStartAngle: 0
                    // Additive rewind animation, independent of the continuous
                    // forward spin. It only changes the visual rotation when
                    // Previous is clicked, never the actual MPRIS playback.
                    property real rewindOffset: 0
                    function cuePrevious() {
                        if (rewindCue.running)
                            rewindCue.stop();
                        rewindCue.from = rewindOffset;
                        rewindCue.to = rewindOffset - 360;
                        rewindCue.start();
                    }
                    NumberAnimation {
                        id: rewindCue
                        target: recordStage
                        property: "rewindOffset"
                        duration: 620
                        easing.type: Easing.OutQuad
                        // Modulo 360 keeps exact visual orientation while
                        // preventing the offset growing on repeated clicks.
                        onFinished: recordStage.rewindOffset = recordStage.rewindOffset % 360
                    }
                    anchors.centerIn: parent
                    width: Math.min(parent.height, parent.width, 178)
                    height: width
                    NumberAnimation {
                        target: recordStage
                        property: "platterAngle"
                        from: recordStage.spinStartAngle
                        to: recordStage.spinStartAngle + 360
                        duration: 12000
                        loops: Animation.Infinite
                        running: recordStage.visible && media.playing && media.artworkMode === "Vinyl"
                        onStopped: recordStage.spinStartAngle = recordStage.platterAngle % 360
                    }
                    Record {
                        id: vinylRecord
                        width: parent.width
                        height: width
                        palette: popup.palette
                        platterAngle: recordStage.platterAngle + recordStage.rewindOffset
                        visible: media.artworkMode === "Vinyl"
                    }
                    // Show the original cover square and still. No cropping, mask,
                    // vinyl rotation, or animation is applied to third-party art.
                    Image {
                        id: originalArtwork
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        source: media.artwork
                        sourceSize: Qt.size(320, 320)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        visible: media.artworkMode === "Artwork"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 5

                QQC.Label {
                    objectName: "trackTitle"
                    Layout.fillWidth: true
                    text: media.track || ("Play something in " + (media.activeSource || "Spotify or Spotifast"))
                    textFormat: Text.PlainText
                    color: popup.cream
                    font.pixelSize: 21
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                QQC.Label {
                    Layout.fillWidth: true
                    visible: Boolean(media.artist)
                    text: media.artist
                    textFormat: Text.PlainText
                    color: popup.muted
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                QQC.Label {
                    text: popup.timeText(seek.pressed ? seek.value : popup.position)
                        + " / " + popup.timeText(media.duration)
                    color: popup.coral
                    visible: Boolean(media.track)
                    font.pixelSize: 13
                }
            }
        }

        QQC.Slider {
            id: seek
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            leftPadding: 6
            rightPadding: 6
            from: 0
            to: Math.max(1, media.duration)
            enabled: (media.player?.canSeek ?? false) && media.duration > 0
            live: false
            value: Math.min(Math.max(0, popup.position), to)
            onMoved: {
                if (media.player?.canSeek)
                    media.player.position = Math.round(value);
            }
            Accessible.name: "Playback position"
            background: Rectangle {
                x: seek.leftPadding
                y: (seek.height - height) / 2
                width: seek.availableWidth
                height: 5
                radius: height / 2
                color: popup.line
                Rectangle {
                    width: parent.width * seek.visualPosition
                    height: parent.height
                    radius: parent.radius
                    color: popup.coral
                }
            }
            handle: Rectangle {
                x: seek.leftPadding + seek.visualPosition * seek.availableWidth - width / 2
                y: (seek.height - height) / 2
                width: 11
                height: width
                radius: width / 2
                color: popup.coral
                border.color: seek.activeFocus ? popup.cream : popup.forest
                visible: seek.enabled
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8
            QQC.Label {
                text: "VOL"
                color: popup.muted
                font.pixelSize: 11
            }
            QQC.Slider {
                id: volumeSlider
                objectName: "volumeSlider"
                Layout.fillWidth: true
                from: 0
                to: 100
                enabled: media.volumeAvailable
                live: false
                value: media.volumeAvailable ? Math.round(media.playerVolume * 100) : 0
                Accessible.name: "Selected player's volume"
                onMoved: media.setPlayerVolume(value / 100)

                // QQC.Slider otherwise inherits the system's accent color
                // (often teal), even when Corner Media Player is burgundy.
                // Both elements bind to popup.palette, so theme switching
                // recolors the control immediately without restarting Plasma.
                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: (volumeSlider.height - height) / 2
                    width: volumeSlider.availableWidth
                    height: 5
                    radius: height / 2
                    color: popup.palette.border

                    Rectangle {
                        width: parent.width * volumeSlider.visualPosition
                        height: parent.height
                        radius: parent.radius
                        color: popup.palette.accent
                    }
                }
                handle: Rectangle {
                    x: volumeSlider.leftPadding
                       + volumeSlider.visualPosition * volumeSlider.availableWidth
                       - width / 2
                    y: (volumeSlider.height - height) / 2
                    width: 14
                    height: width
                    radius: width / 2
                    color: popup.palette.accent
                    border.width: volumeSlider.activeFocus ? 2 : 1
                    border.color: volumeSlider.activeFocus
                        ? popup.palette.text : popup.palette.onAccent
                    opacity: volumeSlider.enabled ? 1 : 0.45
                }
            }
            QQC.Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                color: popup.muted
                text: media.volumeAvailable ? (Math.round(media.playerVolume * 100) + "%") : "N/A"
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 48
                symbol: "media-skip-backward"
                Accessible.name: "Previous track"
                enabled: media.player?.canGoPrevious ?? false
                onClicked: {
                    // Playback navigation already works. Rewind only the
                    // record visual, then let the usual forward spin continue.
                    if (media.player?.canGoPrevious) {
                        recordStage.cuePrevious();
                        media.player.Previous();
                    }
                }
            }
            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 48
                symbol: media.playing ? "media-playback-pause" : "media-playback-start"
                accent: true
                Accessible.name: media.playing ? "Pause" : "Play"
                enabled: media.playing ? (media.player?.canPause ?? false) : (media.player?.canPlay ?? false)
                onClicked: media.playing ? media.player.Pause() : media.player.Play()
            }
            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 48
                symbol: "media-skip-forward"
                Accessible.name: "Next track"
                enabled: media.player?.canGoNext ?? false
                onClicked: media.player.Next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !media.compactMode
            spacing: 8
            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 40
                text: media.launchTarget ? ("Open " + media.launchTarget) : "Choose player"
                enabled: !media.launchingPlayer
                onClicked: {
                    if (media.launchTarget)
                        media.openSelectedPlayer();
                    else
                        sourceMenu.open();
                }
            }
            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 40
                text: "Lyrics"
                Accessible.description: "Search Google for the current track’s lyrics"
                enabled: Boolean(popup.lyricsUrl)
                onClicked: {
                    popup.lyricsError = Qt.openUrlExternally(popup.lyricsUrl)
                        ? "" : "Couldn’t open the lyrics search.";
                }
            }
        }

        QQC.Label {
            Layout.fillWidth: true
            visible: Boolean(text)
            text: popup.lyricsError || media.launchError
            color: popup.coral
            wrapMode: Text.Wrap
            font.pixelSize: 12
        }
    }
}

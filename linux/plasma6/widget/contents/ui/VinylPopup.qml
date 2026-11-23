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
    // Stable vector glyphs. Avoid depending on installed icon-theme names and
    // keep repeat/shuffle/pin/etc. visually compact on every Plasma theme.
    readonly property var utilityPaths: ({
        "shuffle": "M 3 7 H 6 C 10 7 12 17 16 17 H 21 M 18 14 L 21 17 L 18 20 M 3 17 H 6 C 9 17 11 7 16 7 H 21 M 18 4 L 21 7 L 18 10",
        "repeat": "M 4 10 V 7 A 3 3 0 0 1 7 4 H 20 M 17 1 L 20 4 L 17 7 M 20 14 V 17 A 3 3 0 0 1 17 20 H 4 M 7 17 L 4 20 L 7 23",
        "repeat-one": "M 4 10 V 7 A 3 3 0 0 1 7 4 H 20 M 17 1 L 20 4 L 17 7 M 20 14 V 17 A 3 3 0 0 1 17 20 H 4 M 7 17 L 4 20 L 7 23 M 11 10 L 13 9 V 15",
        "pin": "M 8 3 H 16 L 15 8 L 18 11 V 13 H 6 V 11 L 9 8 Z M 12 13 V 22",
        "unpin": "M 8 3 H 16 L 15 8 L 18 11 V 13 H 6 V 11 L 9 8 M 12 13 V 22 M 3 3 L 21 21",
        "compact": "M 3 9 H 9 V 3 M 21 9 H 15 V 3 M 3 15 H 9 V 21 M 21 15 H 15 V 21",
        "expand": "M 9 3 H 3 V 9 M 15 3 H 21 V 9 M 3 15 V 21 H 9 M 21 15 V 21 H 15",
        "artwork": "M 3 4 H 21 V 20 H 3 Z M 3 17 L 8 11 L 12 15 L 16 10 L 21 16 M 15 7 A 1 1 0 1 0 17 7 A 1 1 0 1 0 15 7",
        "vinyl": "M 12 3 A 9 9 0 1 0 12 21 A 9 9 0 1 0 12 3 M 12 9 A 3 3 0 1 0 12 15 A 3 3 0 1 0 12 9 M 12 12 H 12.1"
    })
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
        property bool outlineSymbol: false
        property string hint: ""
        hoverEnabled: true
        QQC.ToolTip.visible: button.hovered && button.hint.length > 0
        QQC.ToolTip.text: button.hint
        QQC.ToolTip.delay: 450
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
            implicitWidth: button.symbol ? (button.small ? 22 : 30) : caption.implicitWidth
            implicitHeight: button.symbol ? (button.small ? 22 : 30) : caption.implicitHeight
            Shape {
                anchors.centerIn: parent
                width: button.small ? 21 : 28
                height: width
                visible: Boolean(button.symbol)
                ShapePath {
                    strokeWidth: button.outlineSymbol ? 2 : -1
                    strokeColor: button.accent ? popup.palette.onAccent : popup.cream
                    fillColor: button.outlineSymbol ? "transparent"
                        : (button.accent ? popup.palette.onAccent : popup.cream)
                    PathSvg {
                        path: button.outlineSymbol
                            ? (popup.utilityPaths[button.symbol] ?? "")
                            : (popup.transportPaths[button.symbol] ?? "")
                    }
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
        anchors.margins: media.compactMode ? 11 : 20
        spacing: media.compactMode ? 6 : 10

        RowLayout {
            Layout.fillWidth: true
            visible: !media.compactMode
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
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                text: "♫"
                Accessible.name: "Choose Spotify or Spotifast"
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: "Select playback source"
                QQC.ToolTip.delay: 450
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
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                text: "◐"
                Accessible.name: "Choose color theme"
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: "Choose color theme"
                QQC.ToolTip.delay: 450
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
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: "shuffle"
                hint: media.shuffleAvailable
                    ? (media.shuffleOn ? "Disable shuffle" : "Enable shuffle")
                    : "Shuffle unavailable"
                Accessible.name: hint
                enabled: media.shuffleAvailable
                accent: media.shuffleOn
                onClicked: media.toggleShuffle()
            }
        }

        // Utility glyphs are intentionally small. Text lives in hover tooltips
        // and accessible names, never in oversized action buttons.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            visible: !media.compactMode
            spacing: 5
            Item { Layout.fillWidth: true }
            PlayerButton {
                objectName: "compactButton"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: "compact"
                hint: "Switch to compact view"
                Accessible.name: hint
                onClicked: media.toggleCompactMode()
            }
            PlayerButton {
                objectName: "pinButton"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: media.pinned ? "unpin" : "pin"
                accent: media.pinned
                hint: media.pinned ? "Unpin: close on click-away" : "Pin player open"
                Accessible.name: hint
                onClicked: media.togglePinned()
            }
            PlayerButton {
                objectName: "repeatButton"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: media.repeatLabel === "Repeat one" ? "repeat-one" : "repeat"
                accent: media.repeatAvailable && media.repeatLabel !== "Repeat off"
                hint: media.repeatAvailable
                    ? (media.repeatLabel + " (click to cycle)")
                    : "Repeat unavailable"
                Accessible.name: hint
                enabled: media.repeatAvailable
                onClicked: media.cycleRepeat()
            }
            PlayerButton {
                objectName: "artworkButton"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: media.artworkMode === "Vinyl" ? "artwork" : "vinyl"
                hint: media.artworkMode === "Vinyl"
                    ? "Show original album artwork" : "Show spinning vinyl"
                Accessible.name: hint
                onClicked: media.toggleArtworkMode()
            }
        }

        // Collapsed view contains only the title, transport buttons and the
        // necessary Expand action. No artist, progress, volume or settings.
        RowLayout {
            objectName: "compactTitleRow"
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            visible: media.compactMode
            spacing: 6
            QQC.Label {
                objectName: "compactTrackTitle"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: media.track || "No track playing"
                textFormat: Text.PlainText
                color: popup.cream
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                QQC.ToolTip.visible: truncated && hovered
                QQC.ToolTip.text: text
                QQC.ToolTip.delay: 450
            }
            PlayerButton {
                objectName: "expandCompactButton"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                small: true
                outlineSymbol: true
                symbol: "expand"
                hint: "Expand player"
                Accessible.name: hint
                onClicked: media.toggleCompactMode()
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
            visible: !media.compactMode
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
            visible: !media.compactMode
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
            objectName: "transportRow"
            Layout.fillWidth: true
            Layout.preferredHeight: media.compactMode ? 37 : 48
            spacing: media.compactMode ? 6 : 8

            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: media.compactMode ? 37 : 48
                small: media.compactMode
                symbol: "media-skip-backward"
                Accessible.name: "Previous track"
                hint: "Previous track"
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
                Layout.preferredHeight: media.compactMode ? 37 : 48
                small: media.compactMode
                symbol: media.playing ? "media-playback-pause" : "media-playback-start"
                accent: true
                Accessible.name: media.playing ? "Pause" : "Play"
                hint: media.playing ? "Pause" : "Play"
                enabled: media.playing ? (media.player?.canPause ?? false) : (media.player?.canPlay ?? false)
                onClicked: media.playing ? media.player.Pause() : media.player.Play()
            }
            PlayerButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: media.compactMode ? 37 : 48
                small: media.compactMode
                symbol: "media-skip-forward"
                Accessible.name: "Next track"
                hint: "Next track"
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
            visible: !media.compactMode && Boolean(text)
            text: popup.lyricsError || media.launchError
            color: popup.coral
            wrapMode: Text.Wrap
            font.pixelSize: 12
        }
    }
}

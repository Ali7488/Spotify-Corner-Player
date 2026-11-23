"""Static regressions for the Plasma 6 widget's custom-colored controls.

These tests check source wiring only; final color appearance still needs a
running KDE Plasma session and a manual theme switch.
"""
from pathlib import Path
import unittest


UI_DIR = Path(__file__).resolve().parents[1] / "widget" / "contents" / "ui"


class WidgetThemeTests(unittest.TestCase):
    def test_slider_theme_bindings(self):
        popup = (UI_DIR / "VinylPopup.qml").read_text(encoding="utf-8")
        self.assertIn("ThemeColors.get(media.themeId)", popup)

        # Keep both sliders styled explicitly. Without a custom background
        # and handle, QtQuick Controls can fall back to the KDE system accent.
        for slider_id in ("seek", "volumeSlider"):
            start = popup.index("id: " + slider_id)
            remaining = popup[start:]
            if slider_id == "seek":
                slider = remaining.split("\n        RowLayout {", 1)[0]
            else:
                slider = remaining.split("\n            QQC.Label {", 1)[0]
            self.assertIn("background: Rectangle", slider, slider_id)
            self.assertIn("handle: Rectangle", slider, slider_id)
            self.assertIn("visualPosition", slider, slider_id)
            self.assertTrue(
                "popup.palette.accent" in slider or "popup.coral" in slider,
                f"{slider_id} must use the selected theme's accent"
            )
            self.assertTrue(
                "popup.palette.border" in slider or "popup.line" in slider,
                f"{slider_id} must use the selected theme's track color"
            )

    def test_volume_preserves_mpris_control(self):
        popup = (UI_DIR / "VinylPopup.qml").read_text(encoding="utf-8")
        section = popup.split("id: volumeSlider", 1)[1].split("\n            QQC.Label {", 1)[0]
        self.assertIn("enabled: media.volumeAvailable", section)
        self.assertIn("value: media.volumeAvailable ? Math.round(media.playerVolume * 100) : 0", section)
        self.assertIn("onMoved: media.setPlayerVolume(value / 100)", section)

    def test_previous_cues_reverse_record_without_changing_media_navigation(self):
        popup = (UI_DIR / "VinylPopup.qml").read_text(encoding="utf-8")
        self.assertIn("property real rewindOffset: 0", popup)
        self.assertIn('property: "rewindOffset"', popup)
        self.assertIn("rewindCue.to = rewindOffset - 360", popup)
        self.assertIn("recordStage.rewindOffset = recordStage.rewindOffset % 360", popup)
        # Only original decorative vinyl rotates; the album art stays square.
        self.assertEqual(
            popup.count("platterAngle: recordStage.platterAngle + recordStage.rewindOffset"), 1
        )
        record = (UI_DIR / "Record.qml").read_text(encoding="utf-8")
        self.assertNotIn("Image {", record)
        self.assertIn("fillMode: Image.PreserveAspectFit", popup)
        self.assertIn('visible: media.artworkMode === "Artwork"', popup)
        self.assertIn('running: recordStage.visible && media.playing && media.artworkMode === "Vinyl"', popup)
        previous = popup.split('Accessible.name: "Previous track"', 1)[1].split(
            "PlayerButton {", 1
        )[0]
        self.assertIn("recordStage.cuePrevious();", previous)
        self.assertIn("media.player.Previous();", previous)
        self.assertLess(previous.index("recordStage.cuePrevious();"),
                        previous.index("media.player.Previous();"))
        next_button = popup.split('Accessible.name: "Next track"', 1)[1].split(
            "PlayerButton {", 1
        )[0]
        self.assertIn("onClicked: media.player.Next()", next_button)
        # Looping forward spin remains independent of the one-shot reverse.
        self.assertIn("to: recordStage.spinStartAngle + 360", popup)
        self.assertIn("loops: Animation.Infinite", popup)


    def test_compact_mode_hides_nonessential_rows(self):
        popup = (UI_DIR / "VinylPopup.qml").read_text(encoding="utf-8")
        main = (UI_DIR / "main.qml").read_text(encoding="utf-8")
        self.assertIn('objectName: "compactTitleRow"', popup)
        self.assertIn('objectName: "compactTrackTitle"', popup)
        self.assertIn('objectName: "expandCompactButton"', popup)
        self.assertIn('objectName: "transportRow"', popup)
        self.assertIn('visible: media.compactMode', popup)
        self.assertGreaterEqual(popup.count('visible: !media.compactMode'), 6)
        self.assertNotIn('Compact mode keeps title, artist, progress', popup)
        self.assertIn('Layout.preferredHeight: compactMode ? 104 : 500', main)
        self.assertIn('Layout.preferredWidth: compactMode ? 276 : 432', main)
        self.assertIn('Layout.preferredHeight: media.compactMode ? 37 : 48', popup)

    def test_small_symbolic_controls_with_hover_tooltips(self):
        popup = (UI_DIR / "VinylPopup.qml").read_text(encoding="utf-8")
        self.assertIn('readonly property var utilityPaths', popup)
        self.assertIn('QQC.ToolTip.visible: button.hovered && button.hint.length > 0', popup)
        self.assertIn('QQC.ToolTip.delay: 450', popup)
        for name in ('shuffleButton', 'pinButton', 'compactButton',
                     'repeatButton', 'artworkButton', 'expandCompactButton'):
            block = popup.split('objectName: "' + name + '"', 1)[1].split(
                '\n            }', 1
            )[0]
            self.assertIn('small: true', block, name)
            self.assertIn('outlineSymbol: true', block, name)
            self.assertIn('Layout.preferredWidth: 28', block, name)
            self.assertIn('hint:', block, name)
            self.assertIn('Accessible.name: hint', block, name)
        self.assertIn('symbol: media.artworkMode === "Vinyl" ? "artwork" : "vinyl"', popup)
        self.assertIn('symbol: media.pinned ? "unpin" : "pin"', popup)


if __name__ == "__main__":
    unittest.main()

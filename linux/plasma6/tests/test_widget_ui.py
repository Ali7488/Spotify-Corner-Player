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


if __name__ == "__main__":
    unittest.main()

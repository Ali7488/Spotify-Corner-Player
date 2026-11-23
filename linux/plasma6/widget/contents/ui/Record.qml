import QtQuick
import "ThemeColors.js" as ThemeColors

// Original decorative vinyl: no third-party album artwork is cropped or rotated.
Item {
    id: record
    property var palette: ThemeColors.get("Forest")
    property real platterAngle: 0

    transform: Rotation {
        origin.x: record.width / 2
        origin.y: record.height / 2
        angle: record.platterAngle
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        border.color: record.palette.vinylBorder
        border.width: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: record.palette.vinylTop }
            GradientStop { position: 0.53; color: record.palette.vinylBottom }
            GradientStop { position: 1.0; color: record.palette.vinylTop }
        }
    }

    Repeater {
        model: 8
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: record.width * (0.92 - index * 0.053)
            height: width
            radius: width / 2
            color: "transparent"
            border.color: index % 2 ? record.palette.vinylBorder : record.palette.vinylGroove
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.48
        height: width
        radius: width / 2
        color: record.palette.vinylLabel
        border.color: record.palette.vinylLabelBorder

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.15
            width: 4
            height: width
            radius: width / 2
            color: record.palette.text
            border.color: record.palette.surface
        }
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: record.palette.vinylCenter
            border.color: record.palette.accent
        }
    }
}

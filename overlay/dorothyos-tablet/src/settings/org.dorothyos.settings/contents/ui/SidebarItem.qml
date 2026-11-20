import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: it
    property string title: ""
    property string iconName: ""
    property color iconColor: Kirigami.Theme.highlightColor
    property bool current: false
    signal clicked()
    Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 14
    color: current ? Kirigami.Theme.highlightColor : (tap.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12) : "transparent")
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 12
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10; color: it.current ? Qt.rgba(1, 1, 1, 0.25) : it.iconColor
            Kirigami.Icon { anchors.centerIn: parent; width: 20; height: 20; source: it.iconName; isMask: true; color: "white" }
        }
        QQC2.Label { Layout.fillWidth: true; text: it.title; font.pixelSize: 16; elide: Text.ElideRight
            color: it.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor }
    }
    TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: it.clicked() }
}

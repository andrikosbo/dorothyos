// One row: coloured icon tile, title, subtitle, optional trailing controls (children), optional chevron; tappable.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: r
    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Kirigami.Theme.highlightColor
    property bool chevron: false
    property bool tappable: false
    property bool separator: true
    property bool busy: false
    default property alias trailing: trail.data
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(64, textCol.implicitHeight + 26)
    Rectangle {
        anchors.fill: parent
        color: tap.pressed ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.18) : "transparent"
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 14
        Rectangle {
            visible: r.iconName.length > 0
            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 11; color: r.iconColor
            Kirigami.Icon { anchors.centerIn: parent; width: 22; height: 22; source: r.iconName; isMask: true; color: "white" }
        }
        ColumnLayout {
            id: textCol; Layout.fillWidth: true; spacing: 1
            QQC2.Label { Layout.fillWidth: true; text: r.title; font.pixelSize: 17; elide: Text.ElideRight }
            QQC2.Label { Layout.fillWidth: true; visible: r.subtitle.length > 0; text: r.subtitle; font.pixelSize: 13; opacity: 0.62; wrapMode: Text.Wrap }
        }
        QQC2.BusyIndicator { visible: r.busy; running: r.busy; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
        Row { id: trail; spacing: 10; Layout.alignment: Qt.AlignVCenter }
        Kirigami.Icon { visible: r.chevron; source: "go-next-symbolic"; Layout.preferredWidth: 20; Layout.preferredHeight: 20; opacity: 0.45 }
    }
    Rectangle {
        visible: r.separator; height: 1; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.left: parent.left; anchors.leftMargin: r.iconName.length > 0 ? 68 : 16
        color: Kirigami.Theme.textColor; opacity: 0.12
    }
    TapHandler { id: tap; enabled: r.tappable; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: r.clicked() }
}

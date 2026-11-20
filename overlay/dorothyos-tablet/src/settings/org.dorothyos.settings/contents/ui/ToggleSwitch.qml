import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool value)
    width: 58; height: 34; radius: 17
    color: checked ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.28)
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
        width: 30; height: 30; radius: 15; y: 2; color: "white"
        x: sw.checked ? sw.width - width - 2 : 2
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    }
    TapHandler { onTapped: sw.toggled(!sw.checked) }
}

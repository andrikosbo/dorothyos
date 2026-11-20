// pipa-top-edge — KWin script: a touch swipe from the top edge of the screen presses the global shortcut of the control-center widget
// ("activate widget @CC_ID@" in the plasmashell component of kglobalaccel, set up by phase13-control-center-user.sh).
// KWin scripts cannot start programs, so the Plasma "executable" data source (also usable inside KWin) runs the qdbus6 call.
import QtQuick
import org.kde.kwin as KWinComponents
import org.kde.plasma.plasma5support as P5Support

Item {
    P5Support.DataSource {
        id: sh
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    property int seq: 0
    KWinComponents.ScreenEdgeHandler {
        edge: KWinComponents.ScreenEdgeHandler.TopEdge
        mode: KWinComponents.ScreenEdgeHandler.Touch
        enabled: true
        onActivated: sh.connectSource("qdbus6 org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component.invokeShortcut 'activate widget @CC_ID@' #" + (++seq))
    }
}

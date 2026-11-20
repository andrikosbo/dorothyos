#!/usr/bin/env python3
"""lockscreen-patch.py SRC_DIR DST_DIR — touch-friendly variant of the Plasma 6.8 lock screen (Xiaomi Pad 6).

Copies every file of the stock lockscreen directory (/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen)
and applies five small, targeted edits. Every edit asserts that the stock text is present exactly once, so a changed
Plasma version makes this script fail loudly instead of producing a half-patched lock screen.

  LockScreenUi.qml
    1. blockUI no longer requires "containsMouse". On a touch screen nothing ever hovers, so the stock rule never held the
       prompt open while the on-screen keyboard was up / a password was being typed.
    2. idle fade-out of the prompt 10 s -> 30 s (typing a password on a touch keyboard takes longer than 10 s).
    3. "Tap to unlock" hint under the clock while the prompt is hidden (the stock screen gives no cue on a touch device).
    4. the prompt is lifted above the on-screen keyboard: the stock screen never moves it, so on a touch device the
       keyboard covered the password field and the user typed blind.
  MainBlock.qml
    5. bigger password field (touch target ~10 mm) and bigger text; the unlock button follows the field's height.
"""
import os, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for name in os.listdir(src):
    p = os.path.join(src, name)
    if os.path.isfile(p):
        shutil.copy2(p, os.path.join(dst, name))


def patch(fname, old, new):
    path = os.path.join(dst, fname)
    s = open(path, encoding="utf-8").read()
    if s.count(old) != 1:
        sys.exit("PATCH FAILED: %s: expected exactly one occurrence, found %d of:\n%s" % (fname, s.count(old), old))
    open(path, "w", encoding="utf-8").write(s.replace(old, new))


patch("LockScreenUi.qml",
      "property bool blockUI: containsMouse && (mainStack.depth > 1",
      "property bool blockUI: (mainStack.depth > 1")
patch("LockScreenUi.qml",
      "            id: fadeoutTimer\n            interval: 10000",
      "            id: fadeoutTimer\n            interval: 30000")
patch("LockScreenUi.qml",
      "        ListModel {\n            id: users\n",
      '''        PlasmaComponents3.Label {
            // pipa: touch cue while only the clock is showing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.gridUnit * 5
            text: i18nd("plasma_shell_org.kde.plasma.desktop", "Tap to unlock")
            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.8)
            opacity: lockScreenRoot.uiVisible ? 0 : 0.85
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }
        }

        ListModel {
            id: users
''')
patch("MainBlock.qml",
      "            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1\n            Layout.fillWidth: true",
      "            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3\n            Layout.fillWidth: true\n            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.75")
patch("MainBlock.qml",
      "Layout.preferredHeight: passwordBox.implicitHeight",
      "Layout.preferredHeight: passwordBox.Layout.preferredHeight")
patch("LockScreenUi.qml",
      "        StackView {\n            id: mainStack\n",
      '''        // pipa: lift the prompt above the on-screen keyboard (keyboard is ~36-39 % of the screen height)
        property bool pipaVkVisible: Keyboards.KWinVirtualKeyboard.visible
        property real pipaLift: 0
        Behavior on pipaLift {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        function pipaRecomputeLift() {
            if (!pipaVkVisible) {
                pipaLift = 0;
                return;
            }
            const keyboardTop = height * (1 - (width > height ? 0.39 : 0.36));
            const boxBottom = mainBlock.y + mainBlock.mapFromItem(mainBlock.mainPasswordBox, 0, mainBlock.mainPasswordBox.height).y;
            pipaLift = Math.max(0, boxBottom + Kirigami.Units.gridUnit * 1.5 - keyboardTop);
        }
        onPipaVkVisibleChanged: pipaLiftTimer.restart()
        Timer {
            id: pipaLiftTimer
            interval: 120
            onTriggered: lockScreenRoot.pipaRecomputeLift()
        }

        StackView {
            id: mainStack
''')
patch("LockScreenUi.qml",
      "            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3\n",
      "            y: -lockScreenRoot.pipaLift\n            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3\n")
print("patched %s -> %s" % (src, dst))

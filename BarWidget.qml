import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "PanelLifecycle.js" as PanelLifecycle

BarWidget {
  id: root

  moduleName: "i3oot.vr"
  property bool pendingToggle: false

  readonly property bool opened: PanelLifecycle.isOpened(panelLoader.item)
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item) {
      panelLoader.item.toggle()
    } else {
      pendingToggle = !pendingToggle
    }
  }

  function open() {
    if (panelLoader.item) PanelLifecycle.open(panelLoader.item)
    else pendingToggle = true
  }

  function close() {
    PanelLifecycle.close(panelLoader.item)
  }

  function closeForPopoutSwitch() {
    PanelLifecycle.closeForPopoutSwitch(panelLoader.item)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
      if (root.pendingToggle) {
        root.pendingToggle = false
        Qt.callLater(function() { if (panelLoader.item) panelLoader.item.open() })
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: Component {
      Item {
        Image {
          id: vrImage
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/icons/vr.svg")
          sourceSize.width: Math.round(width * 2)
          sourceSize.height: Math.round(height * 2)
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: vrImage
          source: vrImage
          colorization: 1.0
          colorizationColor: panelLoader.item && panelLoader.item.pairingReady
            ? button.foreground
            : Qt.rgba(button.foreground.r * 0.52 + Color.popups.background.r * 0.48,
                      button.foreground.g * 0.52 + Color.popups.background.g * 0.48,
                      button.foreground.b * 0.52 + Color.popups.background.b * 0.48, 1)
        }
      }
    }
    tooltipText: "VR Control · WiVRn + WayVR"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.togglePanel()
    }
  }
}

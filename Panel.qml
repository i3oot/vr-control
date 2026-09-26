import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "i3oot.vr"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color background: Color.popups.background
  readonly property color muted: Color.muted
  // Some themes use a very dark `muted` surface color. Lift it toward the
  // theme foreground for secondary text without changing the artwork tint.
  readonly property color secondaryText: Qt.tint(muted, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.52))
  readonly property color accent: Color.accent
  readonly property color artworkColor: headsetConnected ? foreground : accent
  readonly property real artworkOpacity: headsetConnected ? 1.0 : 0.68
  readonly property int defaultHeadsetFrame: 46 // Visor-forward three-quarter pose
  readonly property int defaultControllerFrame: 13
  readonly property var pairingSpinnerFrames: ["|", "/", "-", String.fromCharCode(92)]
  readonly property var headsetInstallChoices: [
    { label: "Meta Quest 2 / 3 / Pro · Meta Store", manufacturer: "Meta Quest" },
    { label: "Meta Quest 1 · WiVRn install wizard", manufacturer: "Meta Quest 1" },
    { label: "Pico · WiVRn install wizard", manufacturer: "Pico" },
    { label: "HTC Vive · WiVRn install wizard", manufacturer: "HTC Vive" },
    { label: "Other Android XR · WiVRn install wizard", manufacturer: "Other Android XR" }
  ]
  property int manualStage: 0
  property bool wivrnInstalled: false
  property bool wivrnUnitAvailable: false
  property bool wivrnActive: false
  property bool avahiActive: false
  property bool wayvrInstalled: false
  property bool xrizerInstalled: false
  property bool wayvrActive: false
  property bool ufwActive: false
  property string ufwRuleState: "unknown"
  property bool headsetConnected: false
  property string headsetSystemName: ""
  property bool aboutOpen: false
  property bool utilityMenuOpen: false
  property bool installMenuOpen: false
  property bool headsetAnimationPlayed: false
  property bool headsetAnimationWrapped: false
  property bool actionBusy: false
  property bool firewallLauncherBusy: false
  property bool pairingBusy: false
  property bool pairingAutoRequestPending: false
  property int pairingSpinnerFrame: 0
  property bool stoppingWayvr: false
  property string actionMessage: ""
  property string pairingPin: ""
  property var hyprMonitors: []
  property string activeWorkspaceId: ""
  property bool hyprlandAvailable: false
  property bool monitorActionBusy: false
  readonly property bool setupNeeded: !wivrnInstalled || !wayvrInstalled || !xrizerInstalled || !wivrnUnitAvailable || !avahiActive
  readonly property bool requiredSoftwareMissing: !wivrnInstalled || !wivrnUnitAvailable || !wayvrInstalled || !xrizerInstalled
  readonly property bool setupReady: !setupNeeded && wivrnActive && wayvrActive
    && ufwActive && ufwRuleState === "open"
  readonly property bool pairingReady: !setupNeeded && wivrnActive && ufwActive && ufwRuleState === "open"
  readonly property string setupActionText: requiredSoftwareMissing ? "Install required software"
    : (setupReady ? "Stop software" : "Configure software")
  readonly property string wivrnSetupState: !wivrnInstalled || !wivrnUnitAvailable || !xrizerInstalled
    ? "MISSING" : (!wivrnActive || !avahiActive ? "INACTIVE" : "READY")
  // Preserve the active theme's intensity while keeping status meaning
  // consistent. Some palettes (for example Hackerman) intentionally map
  // their terminal "red" role to green, so Color.urgent is not always an
  // error color.
  function statusTone(hue) {
    var saturation = Math.max(0.72, Math.min(0.95, accent.hslSaturation))
    var lightness = Math.max(0.58, Math.min(0.70, accent.hslLightness))
    return Qt.hsla(hue, saturation, lightness, 1)
  }
  readonly property color missingColor: statusTone(0.99)
  readonly property color inactiveColor: statusTone(0.105)
  readonly property int currentStage: setupNeeded || !wivrnActive ? 1 : (!headsetConnected ? 2 : 3)
  readonly property int displayedStage: manualStage === 0 ? currentStage : manualStage
  property string expandedSetupItem: ""

  onHeadsetConnectedChanged: {
    if (!headsetConnected) {
      pairingPin = ""
      headsetSystemName = ""
    }
    else {
      pairingAutoRequestPending = false
      ensureWayvrForConnectedHeadset()
      if (!headsetSystemNameCheck.running) headsetSystemNameCheck.running = true
    }
    replayArtAnimations()
    maybeRequestPairingCode()
  }

  onWivrnActiveChanged: {
    maybeRequestPairingCode()
    ensureWayvrForConnectedHeadset()
  }

  onWayvrInstalledChanged: ensureWayvrForConnectedHeadset()

  Component.onCompleted: refresh()

  function replayArtAnimations() {
    headsetAnimationPlayed = false
    headsetAnimationWrapped = false
    headsetWireframe.currentFrame = defaultHeadsetFrame
    leftControllerArt.replayOnce()
    rightControllerArt.replayOnce()
  }

  function ensureWayvrForConnectedHeadset() {
    if (!headsetConnected || !wivrnActive || !wayvrInstalled || wayvrActive
        || wayvrProcess.running || wayvrAutoStartCheck.running) return
    wayvrAutoStartCheck.running = true
  }

  function open() {
    controller.show()
    manualStage = 0
    utilityMenuOpen = false
    installMenuOpen = false
    pairingAutoRequestPending = true
    refresh()
    Qt.callLater(function() { root.maybeRequestPairingCode() })
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function browseStage(direction) {
    const stage = displayedStage
    const nextStage = Math.max(1, Math.min(3, stage + direction))
    manualStage = nextStage === currentStage ? 0 : nextStage
  }
  function chooseHeadsetInstall(choice) {
    installMenuOpen = false
    if (choice.manufacturer === "Meta Quest") {
      openUrl("https://www.meta.com/experiences/7959676140827574/")
      return
    }

    if (!wivrnInstalled) {
      actionMessage = "Install the WiVRn PC stack first, then choose " + choice.manufacturer + " in the headset installer"
      return
    }

    if (!dashboardProcess.running) dashboardProcess.running = true
    actionMessage = choice.manufacturer + " selected · choose Wizard in the WiVRn dashboard to install the matching client"
  }

  function refresh() {
    if (!wivrnDetect.running) wivrnDetect.running = true
    if (!wayvrDetect.running) wayvrDetect.running = true
    if (!xrizerDetect.running) xrizerDetect.running = true
    if (!wivrnUnitCheck.running) wivrnUnitCheck.running = true
    if (!avahiActiveCheck.running) avahiActiveCheck.running = true
    if (!wivrnActiveCheck.running) wivrnActiveCheck.running = true
    if (!wayvrActiveCheck.running) wayvrActiveCheck.running = true
    if (!ufwActiveCheck.running) ufwActiveCheck.running = true
    if (ufwActive && !ufwRulesCheck.running) ufwRulesCheck.running = true
    if (!headsetConnectedCheck.running) headsetConnectedCheck.running = true
    if (headsetConnected && !headsetSystemNameCheck.running) headsetSystemNameCheck.running = true
    if (wivrnActive && !headsetConnected && !pairingPinCheck.running) pairingPinCheck.running = true
    refreshMonitorState()
  }

  function refreshMonitorState() {
    if (!hyprMonitorsCheck.running) hyprMonitorsCheck.running = true
    if (!activeWorkspaceCheck.running) activeWorkspaceCheck.running = true
  }

  function virtualScreenCount() {
    var count = 0
    for (var i = 0; i < hyprMonitors.length; i++) {
      if (/^VR-SCREEN-[0-9]+$/.test(hyprMonitors[i].name || "")) count++
    }
    return count
  }

  function changeVirtualScreenCount(delta) {
    if (!hyprlandAvailable || monitorActionBusy) return
    var names = []
    for (var i = 0; i < hyprMonitors.length; i++) {
      var match = (hyprMonitors[i].name || "").match(/^VR-SCREEN-([0-9]+)$/)
      if (match) names.push({ name: hyprMonitors[i].name, index: Number(match[1]) })
    }

    if (delta > 0) {
      if (names.length >= 4) return
      var nextIndex = 1
      while (names.some(function(output) { return output.index === nextIndex })) nextIndex++
      runMonitorAction(["hyprctl", "output", "create", "headless", "VR-SCREEN-" + nextIndex],
        "Virtual display created · restart WayVR to check screen capture")
    } else {
      if (names.length === 0) return
      names.sort(function(a, b) { return b.index - a.index })
      runMonitorAction(["hyprctl", "output", "remove", names[0].name], "Virtual display removed")
    }
  }

  function moveActiveWorkspaceToMonitor(monitorName) {
    if (!hyprlandAvailable || monitorActionBusy || activeWorkspaceId === "") return
    runMonitorAction(["hyprctl", "dispatch", "moveworkspacetomonitor", activeWorkspaceId, monitorName],
      "Workspace " + activeWorkspaceId + " moved to " + monitorName)
  }

  function runMonitorAction(args, successText) {
    if (monitorActionProcess.running) return
    monitorActionProcess.command = args
    monitorActionProcess.successText = successText
    monitorActionBusy = true
    monitorActionProcess.running = true
  }

  function runAction(args, successText) {
    if (actionProcess.running) return
    actionMessage = ""
    actionProcess.command = args
    actionProcess.successText = successText
    actionProcess.running = true
    actionBusy = true
  }

  function openUrl(url) {
    urlOpener.command = ["xdg-open", url]
    urlOpener.running = true
  }

  function openDashboard() {
    if (wivrnInstalled) {
      if (!dashboardProcess.running) dashboardProcess.running = true
      actionMessage = "Opening WiVRn dashboard"
    } else {
      actionMessage = "Run the VR setup first, then pair your headset here"
    }
  }

  function pairHeadset() {
    if (pairingProcess.running || pairingBusy) return
    if (!wivrnActive) {
      actionMessage = "Start the WiVRn server first, then request a pairing code"
      return
    }
    pairingPin = ""
    pairingSpinnerFrame = 0
    actionMessage = "Requesting a temporary pairing code from WiVRn"
    pairingBusy = true
    pairingProcess.running = true
  }

  function maybeRequestPairingCode() {
    if (!opened || !pairingAutoRequestPending || !wivrnActive || headsetConnected) return
    pairingAutoRequestPending = false
    pairHeadset()
  }

  function openAbout() { aboutOpen = true }

  function setupStack() {
    if (setupLauncher.running) return
    actionMessage = "Setup is running in a floating terminal"
    setupLauncher.running = true
  }

  function removeStack() {
    if (removeLauncher.running) return
    utilityMenuOpen = false
    actionMessage = "Component removal is running in a floating terminal"
    removeLauncher.running = true
  }

  function manageFirewall(operation) {
    if (!ufwActive || firewallLauncher.running) return
    firewallLauncher.operation = operation
    firewallLauncher.command = [
      "omarchy-launch-floating-terminal-with-presentation",
      "bash \"$HOME/.config/omarchy/plugins/i3oot.vr/scripts/firewall-control.sh\" " + operation
    ]
    actionMessage = operation === "open"
      ? "Opening the WiVRn firewall controls in a terminal · confirm the sudo prompt"
      : "Closing plugin managed firewall rules in a terminal · confirm the sudo prompt"
    firewallLauncherBusy = true
    firewallLauncher.running = true
  }

  function startServer() {
    if (!wivrnUnitAvailable) return
    runAction(["systemctl", "--user", "start", "wivrn.service"], "WiVRn server started")
  }

  function stopServer() {
    if (!wivrnUnitAvailable) return
    runAction(["systemctl", "--user", "stop", "wivrn.service"], "WiVRn server stopped")
  }

  function runSetupAction() {
    if (requiredSoftwareMissing) {
      setupStack()
      return
    }
    if (setupReady) {
      if (wayvrProcess.running) wayvrProcess.running = false
      runAction(["sh", "-lc", "systemctl --user stop wivrn.service; result=$?; pkill -x wayvr >/dev/null 2>&1 || true; exit $result"],
                "VR software stopped")
      return
    }
    if (!avahiActive) setupStack()
    else if (!wivrnActive) startServer()

    if (!wayvrActive) startWayvr()

    if (!ufwActive || ufwRuleState !== "open") {
      expandedSetupItem = "firewall"
      if (ufwActive && !firewallLauncherBusy) manageFirewall("open")
    }
  }

  function startWayvr() {
    if (!wayvrInstalled || wayvrProcess.running) return
    wayvrProcess.command = ["wayvr", "--wait"]
    wayvrProcess.running = true
    actionMessage = "WayVR launched · waiting for WiVRn"
  }

  function stopWayvr() {
    if (!wayvrProcess.running) return
    stoppingWayvr = true
    wayvrProcess.running = false
    wayvrActive = false
    actionMessage = "WayVR stopped"
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 100
    running: root.opened && root.pairingBusy
    repeat: true
    onTriggered: root.pairingSpinnerFrame = (root.pairingSpinnerFrame + 1) % root.pairingSpinnerFrames.length
  }

  Process {
    id: wivrnDetect
    command: ["sh", "-lc", "command -v wivrn-dashboard >/dev/null 2>&1 && command -v wivrn-server >/dev/null 2>&1"]
    onExited: function(code) { root.wivrnInstalled = code === 0 }
  }
  Process {
    id: wayvrDetect
    command: ["sh", "-lc", "command -v wayvr >/dev/null 2>&1"]
    onExited: function(code) { root.wayvrInstalled = code === 0 }
  }
  Process {
    id: xrizerDetect
    command: ["pacman", "-Qq", "xrizer"]
    onExited: function(code) { root.xrizerInstalled = code === 0 }
  }
  Process {
    id: wivrnUnitCheck
    command: ["systemctl", "--user", "show", "--property=LoadState", "--value", "wivrn.service"]
    stdout: StdioCollector {
      onStreamFinished: root.wivrnUnitAvailable = text.trim() === "loaded"
    }
  }
  Process {
    id: avahiActiveCheck
    command: ["systemctl", "is-active", "--quiet", "avahi-daemon.service"]
    onExited: function(code) { root.avahiActive = code === 0 }
  }
  Process {
    id: wivrnActiveCheck
    command: ["systemctl", "--user", "is-active", "--quiet", "wivrn.service"]
    onExited: function(code) {
      root.wivrnActive = code === 0
      root.maybeRequestPairingCode()
    }
  }
  Process {
    id: wayvrActiveCheck
    command: ["sh", "-lc", "pgrep -x wayvr >/dev/null 2>&1"]
    onExited: function(code) {
      if (!wayvrProcess.running) root.wayvrActive = code === 0
    }
  }
  Process {
    id: wayvrAutoStartCheck
    command: ["sh", "-lc", "pgrep -x wayvr >/dev/null 2>&1"]
    onExited: function(code) {
      if (!root.headsetConnected || !root.wivrnActive || !root.wayvrInstalled
          || root.wayvrActive || wayvrProcess.running) return
      if (code === 0) root.wayvrActive = true
      else root.startWayvr()
    }
  }
  Process {
    id: hyprMonitorsCheck
    command: ["hyprctl", "-j", "monitors"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var monitors = JSON.parse(text)
          root.hyprMonitors = Array.isArray(monitors) ? monitors : []
          root.hyprlandAvailable = Array.isArray(monitors)
        } catch (error) {
          root.hyprMonitors = []
          root.hyprlandAvailable = false
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) root.hyprlandAvailable = false
    }
  }
  Process {
    id: activeWorkspaceCheck
    command: ["hyprctl", "-j", "activeworkspace"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var workspace = JSON.parse(text)
          root.activeWorkspaceId = workspace && workspace.id > 0 ? String(workspace.id) : ""
        } catch (error) {
          root.activeWorkspaceId = ""
        }
      }
    }
  }
  Process {
    id: monitorActionProcess
    property string successText: ""
    onExited: function(code) {
      root.monitorActionBusy = false
      root.actionMessage = code === 0 ? successText : "Hyprland could not apply that display change"
      root.refreshMonitorState()
    }
  }
  Process {
    id: ufwActiveCheck
    command: ["sh", "-lc", "command -v ufw >/dev/null 2>&1 && grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf && systemctl is-active --quiet ufw"]
    onExited: function(code) {
      root.ufwActive = code === 0
      if (code !== 0) root.ufwRuleState = "unknown"
      else if (!ufwRulesCheck.running) ufwRulesCheck.running = true
    }
  }
  Process {
    id: ufwRulesCheck
    command: ["sudo", "-n", "/usr/bin/ufw", "status", "numbered"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.ufwRuleState = text.indexOf("# Omarchy VR Control") >= 0
          ? "open" : (/^Status:\s*active/m.test(text) ? "closed" : "unknown")
      }
    }
    onExited: function(code) {
      if (code !== 0) root.ufwRuleState = "unknown"
    }
  }
  Process {
    id: headsetConnectedCheck
    command: ["gdbus", "call", "--session", "--dest", "io.github.wivrn.Server",
              "--object-path", "/io/github/wivrn/Server", "--method",
              "org.freedesktop.DBus.Properties.Get", "io.github.wivrn.Server", "HeadsetConnected"]
    stdout: StdioCollector {
      onStreamFinished: root.headsetConnected = text.indexOf("true") >= 0
    }
    onExited: function(code) {
      if (code !== 0) root.headsetConnected = false
    }
  }
  Process {
    id: headsetSystemNameCheck
    command: ["gdbus", "call", "--session", "--dest", "io.github.wivrn.Server",
              "--object-path", "/io/github/wivrn/Server", "--method",
              "org.freedesktop.DBus.Properties.Get", "io.github.wivrn.Server", "SystemName"]
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/'([^']*)'/)
        if (root.headsetConnected) root.headsetSystemName = match ? match[1].trim() : ""
      }
    }
    onExited: function(code) {
      if (code !== 0 && root.headsetConnected) root.headsetSystemName = ""
    }
  }
  Process {
    id: pairingProcess
    command: ["gdbus", "call", "--session", "--dest", "io.github.wivrn.Server",
              "--object-path", "/io/github/wivrn/Server", "--method",
              "io.github.wivrn.Server.EnablePairing", "180"]
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/'([0-9]{6})'/)
        if (match) {
          root.pairingPin = match[1]
          root.actionMessage = "Pairing is enabled briefly · enter this code in the WiVRn headset app"
        } else {
          root.pairingPin = ""
          root.actionMessage = "WiVRn could not enable pairing · end any active headset session and try again"
        }
      }
    }
    onExited: function(code) {
      root.pairingBusy = false
      if (code !== 0) {
        root.pairingPin = ""
        root.actionMessage = "Could not reach the WiVRn pairing service · start the WiVRn server first"
      }
    }
  }
  Process {
    id: pairingPinCheck
    command: ["gdbus", "call", "--session", "--dest", "io.github.wivrn.Server",
              "--object-path", "/io/github/wivrn/Server", "--method",
              "org.freedesktop.DBus.Properties.Get", "io.github.wivrn.Server", "Pin"]
    stdout: StdioCollector {
      onStreamFinished: {
        const match = text.match(/'([0-9]{6})'/)
        root.pairingPin = match ? match[1] : ""
      }
    }
  }
  Process {
    id: actionProcess
    property string successText: "Done"
    onExited: function(code) {
      root.actionBusy = false
      root.actionMessage = code === 0 ? successText : "Action failed · check that the service is installed"
      root.refresh()
    }
  }
  Process {
    id: dashboardProcess
    command: ["wivrn-dashboard"]
  }
  Process {
    id: setupLauncher
    command: [
      "omarchy-launch-floating-terminal-with-presentation",
      "bash \"$HOME/.config/omarchy/plugins/i3oot.vr/scripts/setup.sh\""
    ]
    onExited: root.refresh()
  }
  Process {
    id: removeLauncher
    command: [
      "omarchy-launch-floating-terminal-with-presentation",
      "bash \"$HOME/.config/omarchy/plugins/i3oot.vr/scripts/remove.sh\""
    ]
    onExited: root.refresh()
  }
  Process {
    id: firewallLauncher
    property string operation: "open"
    onExited: function(code) {
      root.firewallLauncherBusy = false
      root.actionMessage = code === 0 ? "Firewall command finished · refresh to update status" : "Firewall command failed or was cancelled"
      if (code === 0) root.ufwRuleState = operation === "open" ? "open" : "closed"
      root.refresh()
    }
  }
  Process { id: urlOpener }
  Process {
    id: wayvrProcess
    command: ["wayvr", "--wait"]
    onStarted: root.wayvrActive = true
    onExited: function(code) {
      root.wayvrActive = false
      if (root.stoppingWayvr) {
        root.stoppingWayvr = false
      } else if (code !== 0) {
        root.actionMessage = "WayVR exited · check its logs"
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: parent.width
          spacing: Style.spacing.md

          Row {
            width: parent.width
            spacing: Style.spacing.md
            z: 2

            Column {
              width: parent.width - utilityMenuAnchor.width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs
              Text {
                text: "VR Control"
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                text: root.displayedStage === 1 ? "Prepare this PC"
                  : (root.displayedStage === 2 ? "Connect the headset"
                    : (root.headsetConnected ? "Headset connected" : "Waiting for headset"))
                color: root.secondaryText
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 0.4
                elide: Text.ElideRight
              }
            }

            Item {
              id: utilityMenuAnchor
              width: utilityMenuButton.implicitWidth
              height: utilityMenuButton.implicitHeight

              PanelActionButton {
                id: utilityMenuButton
                anchors.fill: parent
                iconText: "☰"
                tooltipText: "VR menu"
                foreground: root.foreground
                onClicked: root.utilityMenuOpen = !root.utilityMenuOpen
              }

              Rectangle {
                id: utilityMenu
                visible: root.utilityMenuOpen
                z: 10
                width: Style.space(220)
                height: utilityMenuColumn.implicitHeight + Style.spacing.sm * 2
                anchors.top: parent.bottom
                anchors.topMargin: Style.spacing.xs
                anchors.right: parent.right
                radius: Style.space(12)
                color: root.background
                border.width: 1
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)

                Column {
                  id: utilityMenuColumn
                  anchors.fill: parent
                  anchors.margins: Style.spacing.sm
                  spacing: Style.spacing.xs

                  ActionButton {
                    width: utilityMenuColumn.width
                    text: "Open WiVRn Dashboard"
                    textAlignment: Text.AlignLeft
                    enabled: root.wivrnInstalled
                    onClicked: {
                      root.utilityMenuOpen = false
                      root.openDashboard()
                    }
                  }

                  ActionButton {
                    width: utilityMenuColumn.width
                    text: root.wayvrActive ? "Stop WayVR" : "Launch WayVR"
                    textAlignment: Text.AlignLeft
                    enabled: root.wayvrInstalled && (!root.actionBusy || root.wayvrActive)
                    onClicked: {
                      root.utilityMenuOpen = false
                      root.wayvrActive ? root.stopWayvr() : root.startWayvr()
                    }
                  }

                  Rectangle {
                    width: utilityMenuColumn.width
                    height: 1
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
                  }

                  ActionButton {
                    width: utilityMenuColumn.width
                    text: "Refresh status"
                    textAlignment: Text.AlignLeft
                    onClicked: {
                      root.utilityMenuOpen = false
                      root.refresh()
                    }
                  }

                  ActionButton {
                    width: utilityMenuColumn.width
                    text: "Remove VR components…"
                    textAlignment: Text.AlignLeft
                    enabled: !removeLauncher.running
                    onClicked: root.removeStack()
                  }

                  ActionButton {
                    width: utilityMenuColumn.width
                    text: root.aboutOpen ? "Back to guide" : "About & licenses"
                    textAlignment: Text.AlignLeft
                    onClicked: {
                      root.utilityMenuOpen = false
                      root.aboutOpen = !root.aboutOpen
                    }
                  }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(1.5)
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.05) }
              GradientStop { position: 0.38; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.70) }
              GradientStop { position: 0.68; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.82) }
              GradientStop { position: 1.0; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) }
            }
          }

          Column {
            width: parent.width
            visible: root.aboutOpen
            spacing: Style.spacing.sm

            Text {
              text: "CREDITS & LICENSES"
              color: root.secondaryText
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              font.letterSpacing: 1.2
            }

            StatusCard {
              width: parent.width
              title: "VR Control"
              detail: "Maintained by i3oot · MIT License"
              showIcon: false
              showStateDot: false
            }

            StatusCard {
              width: parent.width
              title: "Required VR stack"
              detail: "WiVRn server + dashboard · GPL-3.0-or-later\nWayVR · GPL-3.0-or-later\nXRizer · GPL-3.0-or-later\nAvahi · LGPL-2.1-or-later"
              showIcon: false
              showStateDot: false

              Flow {
                width: parent.width
                spacing: Style.spacing.xs
                ActionButton { text: "WiVRn ↗"; onClicked: root.openUrl("https://github.com/WiVRn/WiVRn") }
                ActionButton { text: "WayVR ↗"; onClicked: root.openUrl("https://github.com/wayvr-org/wayvr") }
                ActionButton { text: "XRizer ↗"; onClicked: root.openUrl("https://github.com/Supreeeme/xrizer") }
                ActionButton { text: "Avahi ↗"; onClicked: root.openUrl("https://github.com/avahi/avahi") }
              }
            }

            StatusCard {
              width: parent.width
              title: "Bundled artwork"
              detail: "Quest 3 headset · Elin · CC BY 4.0\nTouch Plus controllers · AVILOV · CC BY 4.0\nVR icon · Microsoft Codicons · CC BY 4.0"
              showIcon: false
              showStateDot: false

              Flow {
                width: parent.width
                spacing: Style.spacing.xs
                ActionButton {
                  text: "Headset model ↗"
                  onClicked: root.openUrl("https://sketchfab.com/3d-models/meta-quest-3-65a813833dc04eeeb7d33bdca58c184c")
                }
                ActionButton {
                  text: "Controllers ↗"
                  onClicked: root.openUrl("https://sketchfab.com/3d-models/oculus-quest-3-f4b794fc21784cd2a78392af05e0b597")
                }
                ActionButton {
                  text: "Codicons GitHub ↗"
                  onClicked: root.openUrl("https://github.com/microsoft/vscode-codicons")
                }
              }

              ActionButton {
                text: "Full license notes ↗"
                onClicked: root.openUrl(Qt.resolvedUrl("THIRD_PARTY_NOTICES.md").toString())
              }
            }
          }

          Column {
            width: parent.width
            visible: !root.aboutOpen
            spacing: Style.spacing.sm

            Row {
              id: guideHeaderRow
              width: parent.width
              spacing: Style.spacing.sm

              ActionButton {
                id: previousStageButton
                text: "‹ Back"
                enabled: root.displayedStage > 1
                onClicked: root.browseStage(-1)
              }

              Item {
                width: guideHeaderRow.width - previousStageButton.implicitWidth - nextStageButton.implicitWidth
                  - guideHeaderRow.spacing * 2
                height: 1
              }

              ActionButton {
                id: nextStageButton
                text: "Next ›"
                enabled: root.displayedStage < 3
                onClicked: root.browseStage(1)
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Repeater {
                model: 3
                delegate: Rectangle {
                  required property int index
                  width: (parent.width - Style.spacing.xs * 2) / 3
                  height: Style.space(2)
                  radius: height / 2
                  color: index + 1 < root.displayedStage ? root.accent
                    : (index + 1 === root.displayedStage ? root.foreground
                      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12))
                }
              }
            }

            Column {
              width: parent.width
              visible: root.displayedStage === 1
              spacing: Style.spacing.sm

              Column {
                width: parent.width
                spacing: 0

                SetupTableRow {
                  width: parent.width
                  rowKey: "wivrn"
                  title: "WiVRn"
                  status: root.wivrnSetupState
                  stateColor: root.wivrnSetupState === "READY" ? root.foreground
                    : (root.wivrnSetupState === "MISSING" ? root.missingColor : root.inactiveColor)
                  detail: !root.wivrnInstalled
                    ? "WiVRn is missing. Setup installs WiVRn, WayVR, XRizer, and Avahi discovery."
                    : (!root.wivrnUnitAvailable
                      ? "WiVRn is installed, but its user service needs setup."
                      : (!root.xrizerInstalled
                        ? "XRizer is missing. It lets OpenVR games use the OpenXR runtime."
                        : (!root.avahiActive
                          ? "Avahi local network discovery is inactive."
                          : (root.wivrnActive ? "Server running · ready to pair your headset."
                            : "Installed · start the WiVRn server to continue."))))
                  expanded: root.expandedSetupItem === "wivrn"
                  onToggled: root.expandedSetupItem = expanded ? "" : "wivrn"

                  Row {
                    width: parent.width
                    visible: root.wivrnInstalled
                    spacing: Style.spacing.sm
                    ActionButton {
                      width: (parent.width - parent.spacing) / 2
                      text: root.wivrnActive ? "Stop server" : "Start server"
                      primary: !root.wivrnActive
                      enabled: !root.actionBusy && root.wivrnUnitAvailable
                      onClicked: root.wivrnActive ? root.stopServer() : root.startServer()
                    }
                    ActionButton {
                      width: (parent.width - parent.spacing) / 2
                      text: "Dashboard"
                      enabled: !root.actionBusy
                      onClicked: root.openDashboard()
                    }
                  }

                }

                Rectangle {
                  width: parent.width
                  height: 1
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                }

                SetupTableRow {
                  width: parent.width
                  rowKey: "wayvr"
                  title: "WayVR"
                  status: !root.wayvrInstalled ? "MISSING"
                    : (root.wayvrActive ? (root.headsetConnected ? "READY" : "WAITING") : "INACTIVE")
                  stateColor: !root.wayvrInstalled ? root.missingColor
                    : (root.wayvrActive ? (root.headsetConnected ? root.foreground : root.accent) : root.inactiveColor)
                  detail: !root.wayvrInstalled ? "WayVR is missing. Install and configure the VR stack first."
                    : (root.wayvrActive
                      ? (root.headsetConnected ? "Running · the VR desktop overlay is available."
                        : "Running with --wait · WayVR will attach when the headset connects.")
                      : "Installed · start now; WayVR waits for WiVRn and the headset.")
                  expanded: root.expandedSetupItem === "wayvr"
                  onToggled: root.expandedSetupItem = expanded ? "" : "wayvr"

                  ActionButton {
                    visible: root.wayvrInstalled
                    width: parent.width
                    text: root.wayvrActive ? "Stop WayVR" : "Launch WayVR"
                    primary: !root.wayvrActive
                    enabled: (!root.actionBusy && root.wayvrInstalled) || root.wayvrActive
                    onClicked: root.wayvrActive ? root.stopWayvr() : root.startWayvr()
                  }
                }

                Rectangle {
                  width: parent.width
                  height: 1
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                }

                SetupTableRow {
                  width: parent.width
                  rowKey: "firewall"
                  title: "Firewall"
                  status: root.ufwActive && root.ufwRuleState === "open" ? "READY" : "PORT BLOCKED"
                  stateColor: root.ufwActive && root.ufwRuleState === "open" ? root.foreground : root.missingColor
                  detail: !root.ufwActive
                    ? "UFW is not active. Enable it in system settings to manage WiVRn ports here."
                    : (root.ufwRuleState === "open"
                      ? "WiVRn ports are open for private networks · UDP 5353, TCP/UDP 9757."
                      : (root.ufwRuleState === "closed"
                        ? "Plugin WiVRn port rules are missing. Existing rules may still allow traffic."
                        : "Checking firewall rules…"))
                  expanded: root.expandedSetupItem === "firewall"
                  onToggled: root.expandedSetupItem = expanded ? "" : "firewall"

                  Row {
                    width: parent.width
                    spacing: Style.spacing.sm
                    ActionButton {
                      width: (parent.width - parent.spacing) / 2
                      text: "Open WiVRn ports"
                      textAlignment: Text.AlignLeft
                      primary: true
                      enabled: root.ufwActive && !root.firewallLauncherBusy
                      onClicked: root.manageFirewall("open")
                    }
                    ActionButton {
                      width: (parent.width - parent.spacing) / 2
                      text: "Close plugin rules"
                      textAlignment: Text.AlignLeft
                      enabled: root.ufwActive && !root.firewallLauncherBusy
                      onClicked: root.manageFirewall("close")
                    }
                  }
                }

                ActionButton {
                  width: parent.width
                  text: root.setupActionText
                  primary: true
                  enabled: !root.actionBusy && !setupLauncher.running && !root.firewallLauncherBusy
                  onClicked: root.runSetupAction()
                }
              }

            }

            Column {
              width: parent.width
              visible: root.displayedStage === 2
              spacing: Style.spacing.sm

              StatusCard {
                width: parent.width
                title: root.headsetConnected ? "Headset connected" : "Pair your headset"
                detail: root.headsetConnected
                  ? "The headset is already connected to WiVRn."
                  : "Open WiVRn on the headset and enter the temporary pairing code."
                stateColor: root.pairingPin !== "" ? root.accent : root.muted
                showIcon: false
                showStateDot: false

                Rectangle {
                  visible: !root.headsetConnected
                  width: parent.width
                  height: pinLayout.implicitHeight + Style.spacing.md * 2
                  radius: Style.space(11)
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.085)
                  border.width: 1
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.48)
                  gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.11) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08) }
                  }

                  Column {
                    id: pinLayout
                    width: parent.width - Style.spacing.md * 2
                    anchors.centerIn: parent
                    spacing: Style.spacing.xs

                    Text {
                      width: parent.width - pairingRefreshButton.implicitWidth - Style.spacing.sm
                      text: root.pairingBusy ? "REQUESTING PAIRING CODE" : "PAIRING CODE · ENTER IN THE HEADSET"
                      color: root.secondaryText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      font.letterSpacing: 0.8
                      horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                      id: pairingCodeRow
                      width: parent.width
                      height: pairingCodeText.implicitHeight

                      Text {
                        id: pairingCodeText
                        anchors.fill: parent
                        text: root.pairingBusy
                          ? root.pairingSpinnerFrames[root.pairingSpinnerFrame]
                          : (root.pairingPin !== "" ? root.pairingPin : "------")
                        color: root.pairingPin !== "" || root.pairingBusy ? root.accent : root.secondaryText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading * 1.45
                        font.bold: true
                        font.letterSpacing: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                      }
                    }
                  }

                  PanelActionButton {
                    id: pairingRefreshButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: Style.spacing.xs
                    anchors.topMargin: Style.spacing.xs
                    iconText: "󰑐"
                    tooltipText: root.pairingPin !== "" ? "Refresh pairing code" : "Get pairing code"
                    foreground: root.foreground
                    hoverColor: root.accent
                    size: Style.space(28)
                    enabled: root.wivrnInstalled && !root.pairingBusy
                    onClicked: root.pairHeadset()
                  }
                }

                ActionButton {
                  width: parent.width
                  visible: !root.headsetConnected
                  text: root.installMenuOpen ? "Choose headset manufacturer" : "Install app on headset"
                  primary: true
                  onClicked: root.installMenuOpen = !root.installMenuOpen
                }

                Rectangle {
                  visible: !root.headsetConnected && root.installMenuOpen
                  width: parent.width
                  height: installChoicesColumn.implicitHeight + Style.spacing.md * 2
                  radius: Style.space(11)
                  color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.72)
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.24)

                  Column {
                    id: installChoicesColumn
                    anchors.fill: parent
                    anchors.margins: Style.spacing.md
                    spacing: Style.spacing.sm

                    Text {
                      width: parent.width
                      text: "CHOOSE YOUR HEADSET"
                      color: root.secondaryText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      font.letterSpacing: 0.8
                    }

                    Repeater {
                      model: root.headsetInstallChoices
                      delegate: ActionButton {
                        required property var modelData
                        width: installChoicesColumn.width
                        text: modelData.label
                        onClicked: root.chooseHeadsetInstall(modelData)
                      }
                    }

                    Text {
                      width: parent.width
                      text: "The WiVRn dashboard wizard installs the matching, version-compatible app for other headsets."
                      color: root.secondaryText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width
              visible: root.displayedStage === 3
              spacing: Style.spacing.sm

              Rectangle {
                width: parent.width
                height: headsetArt.height + Style.spacing.md * 2
                radius: Style.space(13)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.055)
                border.width: 1
                border.color: Qt.rgba(root.artworkColor.r, root.artworkColor.g, root.artworkColor.b,
                                       root.headsetConnected ? 0.38 : 0.20)
                gradient: Gradient {
                  GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10) }
                  GradientStop { position: 0.5; color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.15) }
                  GradientStop { position: 1.0; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09) }
                }

                Row {
                  anchors.centerIn: parent
                  spacing: Style.spacing.md

                  ControllerTile {
                    id: leftControllerArt
                    side: "left"
                  }

                  Rectangle {
                    id: headsetArt
                    width: Style.space(116)
                    height: Style.space(84)
                    radius: Style.space(14)
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(root.artworkColor.r, root.artworkColor.g,
                                          root.artworkColor.b, 0.38)

                    AnimatedImage {
                      id: headsetWireframe
                      anchors.fill: parent
                      anchors.margins: Style.space(3)
                      source: Qt.resolvedUrl("assets/icons/headset-turntable.gif")
                      fillMode: Image.PreserveAspectFit
                      playing: root.opened && (headsetHoverArea.containsMouse
                        || (root.headsetConnected && !root.headsetAnimationPlayed))
                      onStatusChanged: {
                        if (status === Image.Ready) {
                          root.headsetAnimationWrapped = false
                          currentFrame = root.defaultHeadsetFrame
                        }
                      }
                      onCurrentFrameChanged: {
                        if (!root.opened || !root.headsetConnected || root.headsetAnimationPlayed
                            || headsetHoverArea.containsMouse || frameCount <= 0) return
                        if (currentFrame === 0) {
                          root.headsetAnimationWrapped = true
                        } else if (root.headsetAnimationWrapped && currentFrame === root.defaultHeadsetFrame) {
                          root.headsetAnimationPlayed = true
                          root.headsetAnimationWrapped = false
                          currentFrame = root.defaultHeadsetFrame
                        }
                      }
                      cache: true
                      smooth: true
                    }

                    MultiEffect {
                      anchors.fill: headsetWireframe
                      source: headsetWireframe
                      colorization: 1.0
                      colorizationColor: root.artworkColor
                      opacity: root.artworkOpacity
                    }

                    MouseArea {
                      id: headsetHoverArea
                      anchors.fill: parent
                      acceptedButtons: Qt.NoButton
                      hoverEnabled: true
                      onEntered: {
                        if (!root.headsetAnimationPlayed) root.headsetAnimationWrapped = false
                        headsetWireframe.currentFrame = root.defaultHeadsetFrame
                      }
                      onExited: {
                        if (!root.headsetAnimationPlayed) root.headsetAnimationWrapped = false
                        headsetWireframe.currentFrame = root.defaultHeadsetFrame
                      }
                    }
                  }

                  ControllerTile {
                    id: rightControllerArt
                    side: "right"
                  }
                }
              }

              Text {
                width: parent.width
                text: root.headsetConnected
                  ? "Connected to " + (root.headsetSystemName || "headset")
                  : "No headset connected"
                color: root.secondaryText
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
              }

              StatusCard {
                width: parent.width
                title: "VR displays"
                detail: "Add virtual screens and route workspaces."
                showIcon: false
                showStateDot: false

                Row {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    width: parent.width - screenCountControls.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Virtual screens · " + root.virtualScreenCount() + " / 4"
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }

                  Row {
                    id: screenCountControls
                    spacing: Style.spacing.xs

                    ActionButton {
                      text: "−"
                      enabled: root.hyprlandAvailable && !root.monitorActionBusy && root.virtualScreenCount() > 0
                      onClicked: root.changeVirtualScreenCount(-1)
                    }

                    ActionButton {
                      text: "+"
                      primary: true
                      enabled: root.hyprlandAvailable && !root.monitorActionBusy && root.virtualScreenCount() < 4
                      onClicked: root.changeVirtualScreenCount(1)
                    }
                  }
                }

                Text {
                  width: parent.width
                  visible: !root.hyprlandAvailable
                  text: "Hyprland unavailable."
                  color: root.secondaryText
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }

                Repeater {
                  model: root.hyprMonitors

                  delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: Style.spacing.xs

                    readonly property bool managedVirtualOutput: /^VR-SCREEN-[0-9]+$/.test(modelData.name || "")
                    readonly property string workspaceLabel: modelData.activeWorkspace
                      ? (modelData.activeWorkspace.name || String(modelData.activeWorkspace.id))
                      : "none"

                    Text {
                      width: parent.width - bindWorkspaceButton.implicitWidth
                        - (removeVirtualOutputButton.visible ? removeVirtualOutputButton.implicitWidth : 0)
                        - parent.spacing * (removeVirtualOutputButton.visible ? 2 : 1)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name + " · WS " + parent.workspaceLabel
                      color: root.secondaryText
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                    }

                    ActionButton {
                      id: bindWorkspaceButton
                      text: "Move here"
                      enabled: root.activeWorkspaceId !== "" && !root.monitorActionBusy
                      onClicked: root.moveActiveWorkspaceToMonitor(modelData.name)
                    }

                    ActionButton {
                      id: removeVirtualOutputButton
                      visible: parent.managedVirtualOutput
                      text: "×"
                      enabled: !root.monitorActionBusy
                      onClicked: root.runMonitorAction(["hyprctl", "output", "remove", modelData.name],
                        "Virtual display removed")
                    }
                  }
                }

              }

            }
          }

        }
      }
    }
  }

  component ControllerTile: Rectangle {
    id: tile
    property string side: "left"
    property bool animationPlayed: false
    property bool animationWrapped: false

    function replayOnce() {
      animationPlayed = false
      animationWrapped = false
      controllerWireframe.currentFrame = root.defaultControllerFrame
    }

    width: Style.space(56)
    height: Style.space(84)
    radius: Style.space(13)
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
    border.width: 1
    border.color: Qt.rgba(root.artworkColor.r, root.artworkColor.g,
                          root.artworkColor.b, 0.38)

    AnimatedImage {
      id: controllerWireframe
      anchors.fill: parent
      anchors.margins: Style.space(2)
      source: Qt.resolvedUrl("assets/icons/controller-"
        + (tile.side === "left" ? "right" : "left") + "-turntable.gif")
      fillMode: Image.PreserveAspectFit
      playing: root.opened && (controllerHoverArea.containsMouse
        || (root.headsetConnected && !tile.animationPlayed))
      onStatusChanged: {
        if (status === Image.Ready) {
          tile.animationWrapped = false
          currentFrame = root.defaultControllerFrame
        }
      }
      onCurrentFrameChanged: {
        if (!root.opened || !root.headsetConnected || tile.animationPlayed
            || controllerHoverArea.containsMouse || frameCount <= 0) return
        if (currentFrame === 0) {
          tile.animationWrapped = true
        } else if (tile.animationWrapped && currentFrame === root.defaultControllerFrame) {
          tile.animationPlayed = true
          tile.animationWrapped = false
          currentFrame = root.defaultControllerFrame
        }
      }
      cache: true
      smooth: true
    }

    MultiEffect {
      anchors.fill: controllerWireframe
      source: controllerWireframe
      colorization: 1.0
      colorizationColor: root.artworkColor
      opacity: root.artworkOpacity
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(2)
      text: tile.side === "left" ? "L" : "R"
      color: root.artworkColor
      opacity: root.artworkOpacity
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    MouseArea {
      id: controllerHoverArea
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      hoverEnabled: true
      onEntered: {
        if (!tile.animationPlayed) tile.animationWrapped = false
        controllerWireframe.currentFrame = root.defaultControllerFrame
      }
      onExited: {
        if (!tile.animationPlayed) tile.animationWrapped = false
        controllerWireframe.currentFrame = root.defaultControllerFrame
      }
    }
  }

  component StatusCard: Rectangle {
    id: card
    property string title: ""
    property string detail: ""
    property color stateColor: "white"
    property string iconText: ""
    property bool showIcon: true
    property bool showStateDot: true
    default property alias content: cardActions.data

    implicitHeight: cardLayout.implicitHeight + Style.spacing.md * 2
    radius: Style.space(13)
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.035)
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.055) }
      GradientStop { position: 1.0; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025) }
    }
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

    Column {
      id: cardLayout
      anchors.fill: parent
      anchors.margins: Style.spacing.md
      spacing: Style.spacing.sm

      Row {
        width: parent.width
        spacing: Style.spacing.sm

        Text {
          id: iconGlyph
          visible: card.showIcon && card.iconText !== ""
          text: card.iconText
          color: root.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width
            - (iconGlyph.visible ? iconGlyph.implicitWidth + parent.spacing : 0)
            - (stateDot.visible ? stateDot.width + parent.spacing : 0)
          spacing: Style.spacing.xs
          Text {
            width: parent.width
            text: card.title
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: card.detail
            color: root.secondaryText
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }

        Rectangle {
          id: stateDot
          visible: card.showStateDot
          width: Style.space(8)
          height: width
          radius: width / 2
          color: card.stateColor
          anchors.verticalCenter: parent.verticalCenter
          opacity: 0.95
        }
      }

      Column {
        id: cardActions
        width: parent.width
        spacing: Style.spacing.sm
      }
    }
  }

  component SetupTableRow: Rectangle {
    id: setupRow
    property string rowKey: ""
    property string title: ""
    property string status: "INACTIVE"
    property string detail: ""
    property color stateColor: root.inactiveColor
    property bool expanded: false
    signal toggled()
    default property alias content: expandedActions.data

    width: parent ? parent.width : implicitWidth
    implicitHeight: rowLayout.implicitHeight + Style.spacing.sm * 2
    color: expanded ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.035) : "transparent"

    Column {
      id: rowLayout
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.xs
      anchors.rightMargin: Style.spacing.xs
      anchors.topMargin: Style.spacing.sm
      anchors.bottomMargin: Style.spacing.sm
      spacing: setupRow.expanded ? Style.spacing.sm : 0

      Item {
        width: parent.width
        height: Math.max(Style.space(38), setupLabel.implicitHeight)

        Row {
          id: setupLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.sm

          Text {
            text: setupRow.title
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          Text {
            text: setupRow.status
            color: setupRow.stateColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            font.letterSpacing: 0.6
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: setupRow.expanded ? "−" : "+"
            color: root.secondaryText
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: setupRow.toggled()
        }
      }

      Column {
        id: expandedActions
        width: parent.width
        visible: setupRow.expanded
        spacing: Style.spacing.sm

        Text {
          width: parent.width
          text: setupRow.detail
          color: root.secondaryText
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component ActionButton: Rectangle {
    id: action
    property string text: ""
    property bool primary: false
    property int textAlignment: Text.AlignHCenter
    signal clicked()

    implicitWidth: label.implicitWidth + Style.spacing.md * 2
    implicitHeight: Style.space(36)
    radius: Style.space(10)
    color: !enabled ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
      : (primary ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                 : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.055))
    border.width: 1
    border.color: primary ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.48)
                          : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
    opacity: enabled ? 1 : 0.52

    Text {
      id: label
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.spacing.md
      anchors.rightMargin: Style.spacing.md
      anchors.verticalCenter: parent.verticalCenter
      text: action.text
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: action.primary
      horizontalAlignment: action.textAlignment
      elide: Text.ElideRight
    }

    MouseArea {
      anchors.fill: parent
      enabled: action.enabled
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: action.clicked()
      onEntered: action.opacity = 0.82
      onExited: action.opacity = action.enabled ? 1 : 0.52
    }
  }
}

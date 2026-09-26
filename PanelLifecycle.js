function isOpened(panel) {
  return !!panel && panel.opened === true;
}

function open(panel) {
  if (panel && typeof panel.open === "function") panel.open();
}

function close(panel) {
  if (panel && typeof panel.close === "function") panel.close();
}

function closeForPopoutSwitch(panel) {
  if (panel && typeof panel.closeForPopoutSwitch === "function")
    panel.closeForPopoutSwitch();
  else
    close(panel);
}

// Keep this file usable as both a Quickshell-imported script and a Node test module.
if (typeof module !== "undefined") {
  module.exports = { isOpened, open, close, closeForPopoutSwitch };
}

const assert = require("node:assert/strict");
const test = require("node:test");

const lifecycle = require("../PanelLifecycle.js");

function makePanel() {
  let isOpen = false;
  const panel = {
    openCalls: 0,
    closeCalls: 0,
    switchCloseCalls: 0,
    get opened() {
      return isOpen;
    },
    open() {
      this.openCalls += 1;
      isOpen = true;
    },
    close() {
      this.closeCalls += 1;
      isOpen = false;
    },
    closeForPopoutSwitch() {
      this.switchCloseCalls += 1;
      this.close();
    },
  };
  return panel;
}

function makeBarOwner(panel) {
  return {
    get opened() {
      return lifecycle.isOpened(panel);
    },
    open() {
      lifecycle.open(panel);
    },
    close() {
      lifecycle.close(panel);
    },
    closeForPopoutSwitch() {
      lifecycle.closeForPopoutSwitch(panel);
    },
  };
}

test("outside dismissal closes through the bar owner and the popup can reopen", () => {
  const panel = makePanel();
  const owner = makeBarOwner(panel);

  owner.open();
  assert.equal(owner.opened, true);

  // KeyboardPanel delegates outside-click dismissal to its owner when present.
  owner.close();
  assert.equal(owner.opened, false);

  owner.open();
  assert.equal(owner.opened, true);
  assert.equal(panel.openCalls, 2);
});

test("popout handoff closes the panel through its switch lifecycle", () => {
  const panel = makePanel();
  const owner = makeBarOwner(panel);

  owner.open();
  owner.closeForPopoutSwitch();

  assert.equal(owner.opened, false);
  assert.equal(panel.switchCloseCalls, 1);
  assert.equal(panel.closeCalls, 1);

  owner.open();
  assert.equal(owner.opened, true);
});

test("lifecycle helpers safely accept an unloaded panel", () => {
  assert.equal(lifecycle.isOpened(null), false);
  assert.doesNotThrow(() => lifecycle.open(null));
  assert.doesNotThrow(() => lifecycle.close(null));
  assert.doesNotThrow(() => lifecycle.closeForPopoutSwitch(null));
});

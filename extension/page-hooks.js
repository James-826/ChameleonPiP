(function () {
  "use strict";

  if (window.__CHAMELEON_PAGE_HOOKS__) return;
  window.__CHAMELEON_PAGE_HOOKS__ = true;

  function isAwake() {
    return (
      Boolean(window.__CHAMELEON_STREAM_AWAKE__) ||
      document.documentElement?.dataset?.chameleonStreamAwake === "1"
    );
  }

  function hookDocProp(prop, fakeVal) {
    const desc = Object.getOwnPropertyDescriptor(Document.prototype, prop);
    if (!desc?.get) return;
    const origGet = desc.get;
    try {
      Object.defineProperty(Document.prototype, prop, {
        configurable: true,
        enumerable: desc.enumerable ?? true,
        get() {
          if (isAwake()) return fakeVal;
          return origGet.call(this);
        },
      });
    } catch (_) {
      try {
        Object.defineProperty(document, prop, {
          configurable: true,
          get() {
            if (isAwake()) return fakeVal;
            return origGet.call(document);
          },
        });
      } catch (_2) {}
    }
  }

  hookDocProp("hidden", false);
  hookDocProp("webkitHidden", false);
  hookDocProp("visibilityState", "visible");

  const GUARDED_EVENTS = new Set(["visibilitychange", "webkitvisibilitychange", "freeze"]);
  const origAdd = EventTarget.prototype.addEventListener;
  const origRemove = EventTarget.prototype.removeEventListener;
  const wrapperMap = new WeakMap();

  function getOrCreateWrapper(listener) {
    let wrapped = wrapperMap.get(listener);
    if (!wrapped) {
      wrapped = function (event) {
        if (isAwake()) return;
        if (typeof listener === "function") {
          return listener.apply(this, arguments);
        }
        return listener.handleEvent(event);
      };
      wrapperMap.set(listener, wrapped);
    }
    return wrapped;
  }

  EventTarget.prototype.addEventListener = function (type, listener, options) {
    if (
      (this === document || this === window) &&
      GUARDED_EVENTS.has(type) &&
      listener &&
      (typeof listener === "function" || typeof listener.handleEvent === "function")
    ) {
      return origAdd.call(this, type, getOrCreateWrapper(listener), options);
    }
    return origAdd.call(this, type, listener, options);
  };

  EventTarget.prototype.removeEventListener = function (type, listener, options) {
    if (
      (this === document || this === window) &&
      GUARDED_EVENTS.has(type) &&
      listener &&
      wrapperMap.has(listener)
    ) {
      return origRemove.call(this, type, wrapperMap.get(listener), options);
    }
    return origRemove.call(this, type, listener, options);
  };

  const stopIfAwake = (e) => {
    if (isAwake()) {
      e.stopImmediatePropagation();
    }
  };
  for (const evName of GUARDED_EVENTS) {
    origAdd.call(document, evName, stopIfAwake, true);
    origAdd.call(window, evName, stopIfAwake, true);
  }
})();

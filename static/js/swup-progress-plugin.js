! function(t, e) {
    "object" == typeof exports && "undefined" != typeof module ? module.exports =
      e() : "function" == typeof define && define.amd ? define(e) : (t || self).SwupProgressPlugin =
      e()
  }(this, function() {
    function t() {
      return t = Object.assign ? Object.assign.bind() : function(t) {
        for (var e = 1; e < arguments.length; e++) {
          var s = arguments[e];
          for (var i in s) Object.prototype.hasOwnProperty.call(s, i) && (t[i] =
            s[i])
        }
        return t
      }, t.apply(this, arguments)
    }
    const e = t => String(t).split(".").map(t => String(parseInt(t || "0", 10)))
      .concat(["0", "0"]).slice(0, 3).join(".");
    class s {
      constructor() {
        this.isSwupPlugin = !0, this.swup = void 0, this.version = void 0,
          this.requires = {}, this.handlersToUnregister = []
      }
      mount() {}
      unmount() {
        this.handlersToUnregister.forEach(t => t()), this.handlersToUnregister = []
      }
      _beforeMount() {
        if (!this.name) throw new Error(
          "You must define a name of plugin when creating a class.")
      }
      _afterUnmount() {}
      _checkRequirements() {
        return "object" != typeof this.requires || Object.entries(this.requires)
          .forEach(([t, s]) => {
            if (! function(t, s, i) {
                const r = function(t, e) {
                  var s;
                  if ("swup" === t) return null != (s = e.version) ? s :
                    ""; {
                    var i;
                    const s = e.findPlugin(t);
                    return null != (i = null == s ? void 0 : s.version) ?
                      i : ""
                  }
                }(t, i);
                return !!r && ((t, s) => s.every(s => {
                  const [, i, r] = s.match(/^([\D]+)?(.*)$/) || [];
                  var n, o;
                  return ((t, e) => {
                    const s = {
                      "": t => 0 === t,
                      ">": t => t > 0,
                      ">=": t => t >= 0,
                      "<": t => t < 0,
                      "<=": t => t <= 0
                    };
                    return (s[e] || s[""])(t)
                  })((o = r, n = e(n = t), o = e(o), n.localeCompare(
                    o, void 0, {
                      numeric: !0
                    })), i || ">=")
                }))(r, s)
              }(t, s = Array.isArray(s) ? s : [s], this.swup)) {
              const e = `${t} ${s.join(", ")}`;
              throw new Error(
                `Plugin version mismatch: ${this.name} requires ${e}`)
            }
          }), !0
      }
      on(t, e, s = {}) {
        var i;
        e = !(i = e).name.startsWith("bound ") || i.hasOwnProperty(
          "prototype") ? e.bind(this) : e;
        const r = this.swup.hooks.on(t, e, s);
        return this.handlersToUnregister.push(r), r
      }
      once(e, s, i = {}) {
        return this.on(e, s, t({}, i, {
          once: !0
        }))
      }
      before(e, s, i = {}) {
        return this.on(e, s, t({}, i, {
          before: !0
        }))
      }
      replace(e, s, i = {}) {
        return this.on(e, s, t({}, i, {
          replace: !0
        }))
      }
      off(t, e) {
        return this.swup.hooks.off(t, e)
      }
    }
    class i {
      constructor(t) {
        let {
          className: e,
          styleAttr: s,
          animationDuration: i,
          minValue: r,
          initialValue: n,
          trickleValue: o
        } = void 0 === t ? {} : t;
        this.value = 0, this.visible = !1, this.hiding = !1, this.className =
          "progress-bar", this.styleAttr =
          "data-progressbar-styles data-swup-theme", this.animationDuration =
          300, this.minValue = .1, this.initialValue = .25, this.trickleValue =
          .03, this.trickleInterval = void 0, this.styleElement = void 0,
          this.progressElement = void 0, this.trickle = () => {
            const t = Math.random() * this.trickleValue;
            this.setValue(this.value + t)
          }, void 0 !== e && (this.className = String(e)), void 0 !== s && (
            this.styleAttr = String(s)), void 0 !== i && (this.animationDuration =
            Number(i)), void 0 !== r && (this.minValue = Number(r)), void 0 !==
          n && (this.initialValue = Number(n)), void 0 !== o && (this.trickleValue =
            Number(o)), this.styleElement = this.createStyleElement(), this.progressElement =
          this.createProgressElement()
      }
      get defaultStyles() {
        return `\n\t\t.${this.className} {\n\t\t\tposition: fixed;\n\t\t\tdisplay: block;\n\t\t\ttop: 0;\n\t\t\tleft: 0;\n\t\t\theight: 3px;\n\t\t\tbackground-color: black;\n\t\t\tz-index: 9999;\n\t\t\ttransition:\n\t\t\t\twidth ${this.animationDuration}ms ease-out,\n\t\t\t\topacity ${this.animationDuration/2}ms ${this.animationDuration/2}ms ease-in;\n\t\t\ttransform: translate3d(0, 0, 0);\n\t\t}\n\t`
      }
      show() {
        this.visible || (this.visible = !0, this.installStyleElement(), this.installProgressElement(),
          this.startTrickling())
      }
      hide() {
        this.visible && !this.hiding && (this.hiding = !0, this.fadeProgressElement(
          () => {
            this.uninstallProgressElement(), this.stopTrickling(), this.visible = !
              1, this.hiding = !1
          }))
      }
      setValue(t) {
        this.value = Math.min(1, Math.max(this.minValue, t)), this.refresh()
      }
      installStyleElement() {
        document.head.insertBefore(this.styleElement, document.head.firstChild)
      }
      installProgressElement() {
        this.progressElement.style.width = "0%", this.progressElement.style.opacity =
          "1", document.documentElement.insertBefore(this.progressElement,
            document.body), this.progressElement.scrollTop = 0, this.setValue(
            Math.random() * this.initialValue)
      }
      fadeProgressElement(t) {
        this.progressElement.style.opacity = "0", setTimeout(t, 1.5 * this.animationDuration)
      }
      uninstallProgressElement() {
        this.progressElement.parentNode && document.documentElement.removeChild(
          this.progressElement)
      }
      startTrickling() {
        this.trickleInterval || (this.trickleInterval = window.setInterval(
          this.trickle, this.animationDuration))
      }
      stopTrickling() {
        window.clearInterval(this.trickleInterval), delete this.trickleInterval
      }
      refresh() {
        requestAnimationFrame(() => {
          this.progressElement.style.width = 100 * this.value + "%"
        })
      }
      createStyleElement() {
        const t = document.createElement("style");
        return this.styleAttr.split(" ").forEach(e => t.setAttribute(e, "")),
          t.textContent = this.defaultStyles, t
      }
      createProgressElement() {
        const t = document.createElement("div");
        return t.className = this.className, t
      }
    }
    return class extends s {
      constructor(t) {
        void 0 === t && (t = {}), super(), this.name = "SwupProgressPlugin",
          this.defaults = {
            className: "swup-progress-bar",
            delay: 300,
            transition: 300,
            minValue: .1,
            initialValue: .25,
            finishAnimation: !0
          }, this.options = void 0, this.progressBar = void 0, this.showProgressBarTimeout =
          void 0, this.hideProgressBarTimeout = void 0, this.options = { ...
            this.defaults,
            ...t
          };
        const {
          className: e,
          minValue: s,
          initialValue: r,
          transition: n
        } = this.options;
        this.progressBar = new i({
          className: e,
          minValue: s,
          initialValue: r,
          animationDuration: n
        })
      }
      mount() {
        this.on("visit:start", this.startShowingProgress), this.on(
          "page:view", this.stopShowingProgress)
      }
      startShowingProgress() {
        this.progressBar.setValue(0), this.showProgressBarAfterDelay()
      }
      stopShowingProgress() {
        this.progressBar.setValue(1), this.options.finishAnimation ? this.finishAnimationAndHideProgressBar() :
          this.hideProgressBar()
      }
      showProgressBar() {
        this.cancelHideProgressBarTimeout(), this.progressBar.show()
      }
      showProgressBarAfterDelay() {
        this.cancelShowProgressBarTimeout(), this.cancelHideProgressBarTimeout(),
          this.showProgressBarTimeout = window.setTimeout(this.showProgressBar
            .bind(this), this.options.delay)
      }
      hideProgressBar() {
        this.cancelShowProgressBarTimeout(), this.progressBar.hide()
      }
      finishAnimationAndHideProgressBar() {
        this.cancelShowProgressBarTimeout(), this.hideProgressBarTimeout =
          window.setTimeout(this.hideProgressBar.bind(this), this.options.transition)
      }
      cancelShowProgressBarTimeout() {
        window.clearTimeout(this.showProgressBarTimeout), delete this.showProgressBarTimeout
      }
      cancelHideProgressBarTimeout() {
        window.clearTimeout(this.hideProgressBarTimeout), delete this.hideProgressBarTimeout
      }
    }
  });
  
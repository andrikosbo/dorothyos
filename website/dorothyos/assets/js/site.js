/* DorothyOS landing page — two small enhancements; the page works without any of them. */
(function () {
  "use strict";

  // 1. header gets a hairline once the page has scrolled
  var nav = document.querySelector(".nav");
  if (nav) {
    var onScroll = function () { nav.classList.toggle("scrolled", window.scrollY > 8); };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  // 2. copy buttons on the code blocks
  document.querySelectorAll("[data-code]").forEach(function (box) {
    var btn = box.querySelector("[data-copy]");
    var code = box.querySelector("code");
    if (!btn || !code) { return; }
    btn.hidden = false;
    var label = btn.querySelector("span");
    btn.addEventListener("click", function () {
      var text = code.textContent;
      var done = function () {
        label.textContent = btn.getAttribute("data-done");
        setTimeout(function () { label.textContent = btn.getAttribute("data-label"); }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () {});
      } else {
        var ta = document.createElement("textarea");
        ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0";
        document.body.appendChild(ta); ta.select();
        try { document.execCommand("copy"); done(); } catch (e) { /* nothing to do */ }
        document.body.removeChild(ta);
      }
    });
  });
})();

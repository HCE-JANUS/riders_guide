// HCE Riders Guide — table-of-contents panel toggle.
// Vanilla JS, no dependencies. Everything else in this template (callout
// labels, scrollable tables) is pure CSS so it still works if this never
// runs.
(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    var toc = document.getElementById("table-of-contents");
    var content = document.getElementById("content");
    if (!toc || !content) return;

    var tocHeading = toc.querySelector("h2");

    var toggle = document.createElement("button");
    toggle.id = "toc-toggle";
    toggle.type = "button";
    toggle.textContent = "Table of Contents";
    toggle.setAttribute("aria-expanded", "false");
    toggle.setAttribute("aria-controls", "table-of-contents");
    content.insertBefore(toggle, content.firstChild);

    var closeBtn = document.createElement("button");
    closeBtn.id = "toc-close";
    closeBtn.type = "button";
    closeBtn.textContent = "Close";
    if (tocHeading) tocHeading.appendChild(closeBtn);

    function open() {
      document.body.classList.add("toc-open");
      toggle.setAttribute("aria-expanded", "true");
    }
    function close() {
      document.body.classList.remove("toc-open");
      toggle.setAttribute("aria-expanded", "false");
    }

    toggle.addEventListener("click", function () {
      document.body.classList.contains("toc-open") ? close() : open();
    });
    closeBtn.addEventListener("click", close);

    // Following a link inside the panel should dismiss it (mobile: the
    // panel covers the whole screen, so the target section is hidden
    // behind it until this closes).
    toc.addEventListener("click", function (evt) {
      if (evt.target.tagName === "A") close();
    });

    document.addEventListener("keydown", function (evt) {
      if (evt.key === "Escape") close();
    });
  });
})();

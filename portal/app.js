/* Demo PIN is compared as four digits in this file.
   A real build checks pinSha256 on the server and does not decide access here.
   Notification.requestPermission runs only from the Turn on alerts click. */
(function () {
  var DEMO_PIN = "1234";
  var DEMO_KEY = "rapidrx-demo";
  var RANK = { high: 0, medium: 1, low: 2 };
  var KIND = {
    missed_dose: "Missed dose",
    unanswered_call: "Unanswered call",
    new_prescription: "New prescription",
  };

  document.addEventListener("DOMContentLoaded", function () {
    var page = document.body.getAttribute("data-page");
    if (page === "overview") startOverview();
    if (page === "alerts") startAlerts();
    if (page === "demo") startDemo();
    var alertsBtn = document.getElementById("turn-on-alerts");
    if (alertsBtn) alertsBtn.addEventListener("click", onTurnOnAlerts);
  });

  function onTurnOnAlerts() {
    var status = document.getElementById("alerts-permission");
    if (
      typeof Notification === "undefined" ||
      typeof Notification.requestPermission !== "function"
    ) {
      status.textContent =
        "This browser has no notification permission API. The list on this page is the only alert surface here.";
      return;
    }
    Notification.requestPermission().then(function (result) {
      status.textContent =
        result === "granted"
          ? "Alerts are allowed in this browser."
          : "Alerts were not allowed (" + result + ").";
    });
  }

  function startDemo() {
    var btn = document.getElementById("load-demo");
    var status = document.getElementById("demo-status");
    btn.addEventListener("click", function () {
      sessionStorage.setItem(DEMO_KEY, "1");
      status.textContent = "Overview will load the labeled demo fixture.";
      location.href = "index.html";
    });
  }

  function startAlerts() {
    var list = document.getElementById("alert-list");
    fetch("demo-family.json")
      .then(function (r) {
        if (!r.ok) throw new Error("missing");
        return r.json();
      })
      .then(function (data) {
        list.replaceChildren();
        data.alerts.forEach(function (item) {
          var li = document.createElement("li");
          var label = KIND[item.kind] || item.kind;
          var extra = item.medicine ? " · " + item.medicine : "";
          li.textContent = label + extra + " · " + item.time;
          list.append(li);
        });
      })
      .catch(function () {
        list.replaceChildren();
        ["Missed dose", "Unanswered call", "New prescription"].forEach(function (name) {
          var li = document.createElement("li");
          li.textContent = name + " — demo fixture did not load.";
          list.append(li);
        });
      });
  }

  function startOverview() {
    var panel = document.getElementById("panel");
    if (sessionStorage.getItem(DEMO_KEY) !== "1") {
      panel.replaceChildren();
      var p = document.createElement("p");
      p.textContent = "No caretaker copy is loaded. The phone keeps the records.";
      var link = document.createElement("a");
      link.href = "demo.html";
      link.textContent = "Open Demo to load the labeled fixture";
      panel.append(p, link);
      return;
    }
    fetch("demo-family.json")
      .then(function (r) {
        if (!r.ok) throw new Error("missing");
        return r.json();
      })
      .then(function (data) {
        var state = { data: data, mode: "family", unlocked: false };
        paint(panel, state);
      })
      .catch(function () {
        panel.textContent = "The demo fixture could not be loaded.";
      });
  }

  function paint(panel, state) {
    var data = state.data;
    var commercial = state.mode === "commercial" && state.unlocked;
    var today = data.doses.filter(function (d) {
      return d.day === data.asOf;
    });
    var week = data.doses.filter(function (d) {
      return daysBefore(data.asOf, d.day) < 7;
    });

    panel.replaceChildren();
    panel.append(banner(data.label || "Demo"));
    panel.append(toggle(state, panel));

    if (state.mode === "commercial" && !state.unlocked) {
      panel.append(pinForm(state, panel));
      return;
    }

    panel.append(countBlock("Today", today));
    if (!commercial) panel.append(countBlock("This week", week));
    panel.append(missedBlock(commercial ? today : week));
    panel.append(notesBlock(data.notes));
    panel.append(scheduleBlock(data.medicines));
    if (!commercial) panel.append(familyBlock(data));
  }

  function toggle(state, panel) {
    var bar = document.createElement("div");
    bar.className = "toggle";
    bar.setAttribute("role", "group");
    bar.setAttribute("aria-label", "Caretaker view");
    bar.append(
      modeButton("Family view", state.mode === "family", function () {
        state.mode = "family";
        state.unlocked = false;
        paint(panel, state);
      }),
      modeButton("Commercial view", state.mode === "commercial", function () {
        state.mode = "commercial";
        paint(panel, state);
      })
    );
    return bar;
  }

  function modeButton(text, pressed, onClick) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.textContent = text;
    btn.setAttribute("aria-pressed", pressed ? "true" : "false");
    btn.addEventListener("click", onClick);
    return btn;
  }

  function pinForm(state, panel) {
    var form = document.createElement("form");
    var label = document.createElement("label");
    label.htmlFor = "pin";
    label.textContent = "4-digit PIN";
    var input = document.createElement("input");
    input.id = "pin";
    input.inputMode = "numeric";
    input.autocomplete = "off";
    input.maxLength = 4;
    input.pattern = "[0-9]{4}";
    input.setAttribute("aria-describedby", "pin-help");
    var submit = document.createElement("button");
    submit.type = "submit";
    submit.textContent = "Open commercial view";
    var error = document.createElement("p");
    error.className = "error";
    error.setAttribute("role", "alert");
    var help = document.createElement("p");
    help.id = "pin-help";
    help.className = "muted";
    help.textContent =
      "Demo PIN is 1234. This page compares those digits. A real build checks the SHA-256 on the server.";
    form.append(label, input, submit, error, help);
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var digits = input.value.trim();
      if (!/^\d{4}$/.test(digits) || digits !== DEMO_PIN) {
        error.textContent = "That PIN is not right.";
        return;
      }
      state.unlocked = true;
      paint(panel, state);
    });
    return form;
  }

  function banner(text) {
    var p = document.createElement("p");
    p.className = "banner";
    p.textContent = text;
    return p;
  }

  function countBlock(title, rows) {
    var section = document.createElement("section");
    var h = document.createElement("h2");
    h.textContent = title;
    var ul = document.createElement("ul");
    ul.className = "counts";
    ["taken", "missed", "upcoming"].forEach(function (status) {
      var n = rows.filter(function (d) {
        return d.status === status;
      }).length;
      var li = document.createElement("li");
      var strong = document.createElement("strong");
      strong.className = status;
      strong.textContent = String(n);
      var word = document.createElement("span");
      word.textContent = status;
      li.append(strong, word);
      ul.append(li);
    });
    section.append(h, ul);
    if (title === "Today") {
      rows.forEach(function (d) {
        section.append(doseRow(d));
      });
    }
    return section;
  }

  function doseRow(d) {
    var p = document.createElement("p");
    p.className = "row card";
    var name = document.createElement("span");
    name.textContent = d.medicine + " · " + d.time;
    var status = document.createElement("span");
    status.className = d.status;
    status.textContent = d.status;
    p.append(name, status);
    return p;
  }

  function missedBlock(rows) {
    var section = document.createElement("section");
    var h = document.createElement("h2");
    h.textContent = "Missed doses";
    section.append(h);
    var missed = rows
      .filter(function (d) {
        return d.status === "missed";
      })
      .slice()
      .sort(function (a, b) {
        return a.day < b.day ? 1 : a.day > b.day ? -1 : a.time < b.time ? -1 : 1;
      });
    if (!missed.length) {
      var empty = document.createElement("p");
      empty.textContent = "Nothing missed.";
      section.append(empty);
      return section;
    }
    missed.forEach(function (d) {
      var p = document.createElement("p");
      p.className = "card";
      p.textContent = d.medicine + " · " + d.time + " · " + d.day;
      section.append(p);
    });
    return section;
  }

  function notesBlock(notes) {
    var section = document.createElement("section");
    var h = document.createElement("h2");
    h.textContent = "Notes";
    section.append(h);
    notes
      .slice()
      .sort(function (a, b) {
        return (RANK[a.priority] ?? 9) - (RANK[b.priority] ?? 9);
      })
      .forEach(function (note) {
        var p = document.createElement("p");
        p.className = "card" + (note.priority === "high" ? " note-high" : "");
        var pill = document.createElement("span");
        pill.className = "pill";
        pill.textContent = note.priority;
        p.append(pill, document.createTextNode(note.text));
        section.append(p);
      });
    return section;
  }

  function scheduleBlock(medicines) {
    var section = document.createElement("section");
    var h = document.createElement("h2");
    h.textContent = "Schedule";
    section.append(h);
    medicines.forEach(function (med) {
      var p = document.createElement("p");
      p.className = "row card";
      var name = document.createElement("span");
      name.textContent = med.name;
      var time = document.createElement("span");
      time.textContent = med.time;
      p.append(name, time);
      section.append(p);
    });
    return section;
  }

  function familyBlock(data) {
    var section = document.createElement("section");
    var h = document.createElement("h2");
    h.textContent = "For family";
    var alert = document.createElement("p");
    alert.className = "card";
    alert.textContent = data.familyOnly.alertLabel;
    var stay = document.createElement("p");
    stay.className = "muted";
    stay.textContent =
      "Health profile, Ayushman, and prescription photos stay on the phone. They are not in this copy.";
    section.append(h, alert, stay);
    return section;
  }

  function daysBefore(asOf, day) {
    var a = Date.parse(asOf + "T00:00:00Z");
    var b = Date.parse(day + "T00:00:00Z");
    return Math.round((a - b) / 86400000);
  }
})();

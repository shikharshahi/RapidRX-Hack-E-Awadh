/* Demo PIN is compared as four digits in this file.
   A real build checks pinSha256 on the server and does not decide access here.
   Notification.requestPermission runs only from the Turn on alerts click. */
(function () {
  var DEMO_PIN = "1234";
  var DEMO_KEY = "rapidrx-demo";
  var COPY_KEY = "rapidrx-copy";
  var FS =
    "https://firestore.googleapis.com/v1/projects/rapidrx-portal/databases/(default)/documents/patients/demo/";
  var RANK = { high: 0, medium: 1, low: 2 };
  var KIND = {
    missed_dose: "Missed dose",
    unanswered_call: "Unanswered call",
    new_prescription: "New prescription",
    medicine_alert: "Medicine alert",
  };

  document.addEventListener("DOMContentLoaded", function () {
    var page = document.body.getAttribute("data-page");
    if (page === "overview") startOverview();
    if (page === "alerts") startAlerts();
    if (page === "demo") startDemo();
    if (page === "sync") startSync();
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
      status.textContent = "Opening the family overview.";
      location.href = "overview.html";
    });
  }

  function startSync() {
    var status = document.getElementById("sync-status");
    document.getElementById("sync-app").addEventListener("click", function () {
      status.textContent = "Asking Firebase for the caretaker copy.";
      Promise.all([
        fetch(FS + "doses").then(readOk),
        fetch(FS + "alerts").then(readOk),
      ])
        .then(function (parts) {
          var data = copyFromFirebase(docsOf(parts[0]), docsOf(parts[1]));
          if (!data.doses.length && !data.alerts.length) {
            status.textContent =
              "Firebase has no caretaker copy yet. The phone has not published a dose or an alert.";
            return;
          }
          saveCopy(data);
          status.textContent = "Opening the family overview.";
          location.href = "overview.html";
        })
        .catch(function () {
          status.textContent =
            "Firebase did not return a copy. A linked caretaker is the only reader, and this page has no caretaker sign-in.";
        });
    });
    document.getElementById("load-demo").addEventListener("click", function () {
      fetch("demo-family.json")
        .then(readOk)
        .then(function (data) {
          if (!data.label) data.label = "Labeled demo. Not a live record.";
          saveCopy(data);
          location.href = "overview.html";
        })
        .catch(function () {
          status.textContent = "The labeled demo could not be loaded.";
        });
    });
  }

  function startAlerts() {
    var list = document.getElementById("alert-list");
    var cached = readCopy();
    if (cached) {
      paintAlerts(list, cached.alerts || []);
      watchBay(list, cached.alerts || []);
      return;
    }
    if (sessionStorage.getItem(DEMO_KEY) !== "1") {
      list.replaceChildren();
      var li = document.createElement("li");
      li.className = "qrow";
      var msg = document.createElement("div");
      msg.className = "msg";
      var title = document.createElement("b");
      title.textContent = "No caretaker copy is loaded.";
      var detail = document.createElement("small");
      detail.textContent = "Sync from the app first.";
      msg.append(title, detail);
      li.append(msg);
      list.append(li);
      watchBay(list, []);
      return;
    }
    fetch("demo-family.json")
      .then(function (r) {
        if (!r.ok) throw new Error("missing");
        return r.json();
      })
      .then(function (data) {
        paintAlerts(list, data.alerts || []);
        watchBay(list, data.alerts || []);
      })
      .catch(function () {
        list.replaceChildren();
        ["Missed dose", "Unanswered call", "New prescription"].forEach(function (name) {
          var li = document.createElement("li");
          li.className = "qrow";
          var msg = document.createElement("div");
          msg.className = "msg";
          var title = document.createElement("b");
          title.textContent = name;
          var detail = document.createElement("small");
          detail.textContent = "The list did not load.";
          msg.append(title, detail);
          li.append(msg);
          list.append(li);
        });
        watchBay(list, []);
      });
  }

  function watchBay(list, base) {
    function tick() {
      fetch("/api/demo-alerts")
        .then(function (r) {
          if (!r.ok) throw new Error("skip");
          return r.json();
        })
        .then(function (live) {
          if (!Array.isArray(live) || !live.length) return;
          paintAlerts(list, live.concat(base));
        })
        .catch(function () {});
    }
    tick();
    setInterval(tick, 3000);
  }

  function pillMarks(count) {
    var n = count || 1;
    if (n < 1) n = 1;
    if (n > 4) n = 4;
    var wrap = document.createElement("span");
    wrap.className = "pill-marks";
    wrap.setAttribute(
      "aria-label",
      n === 1 ? "1 tablet" : n + " tablets"
    );
    for (var i = 0; i < n; i++) {
      var mark = document.createElement("i");
      mark.className = "pill-art";
      mark.setAttribute("aria-hidden", "true");
      wrap.append(mark);
    }
    return wrap;
  }

  function startOverview() {
    var panel = document.getElementById("panel");
    if (sessionStorage.getItem(DEMO_KEY) !== "1") {
      panel.replaceChildren();
      var card = document.createElement("div");
      card.className = "qr-card sheet";
      var title = document.createElement("h2");
      title.textContent = "No caretaker copy is loaded.";
      var hint = document.createElement("p");
      hint.className = "hint";
      hint.textContent = "The phone keeps the records.";
      var link = document.createElement("a");
      link.className = "btn";
      link.href = "sync.html";
      link.textContent = "Sync from the app";
      card.append(title, hint, link);
      panel.append(card);
      return;
    }
    var cached = readCopy();
    if (cached) {
      paint(panel, { data: cached, mode: "family", unlocked: false });
      return;
    }
    fetch("demo-family.json")
      .then(readOk)
      .then(function (data) {
        paint(panel, { data: data, mode: "family", unlocked: false });
      })
      .catch(function () {
        panel.textContent = "The family overview could not be loaded.";
      });
  }

  function readCopy() {
    var raw = sessionStorage.getItem(COPY_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function saveCopy(data) {
    sessionStorage.setItem(COPY_KEY, JSON.stringify(data));
    sessionStorage.setItem(DEMO_KEY, "1");
  }

  function readOk(response) {
    if (!response.ok) throw new Error(String(response.status));
    return response.json();
  }

  function docsOf(body) {
    return (body && body.documents) || [];
  }

  function field(doc, name) {
    var value = doc.fields && doc.fields[name];
    return (value && value.stringValue) || "";
  }

  function todayIso() {
    var d = new Date();
    var month = String(d.getMonth() + 1);
    var day = String(d.getDate());
    if (month.length < 2) month = "0" + month;
    if (day.length < 2) day = "0" + day;
    return d.getFullYear() + "-" + month + "-" + day;
  }

  function copyFromFirebase(doseDocs, alertDocs) {
    var asOf = todayIso();
    var doses = doseDocs
      .map(function (doc) {
        return {
          day: field(doc, "day") || asOf,
          medicine: field(doc, "medicine"),
          time: field(doc, "time"),
          status: field(doc, "status"),
        };
      })
      .filter(function (dose) {
        return dose.medicine && dose.time && /^(taken|missed|upcoming)$/.test(dose.status);
      });
    var alerts = alertDocs
      .map(function (doc) {
        var item = { kind: field(doc, "kind"), time: field(doc, "time") };
        var medicine = field(doc, "medicine");
        if (medicine) item.medicine = medicine;
        return item;
      })
      .filter(function (item) {
        return item.kind && item.time;
      });
    var seen = {};
    var medicines = [];
    doses.forEach(function (dose) {
      var key = dose.medicine + "|" + dose.time;
      if (seen[key]) return;
      seen[key] = true;
      medicines.push({ name: dose.medicine, time: dose.time });
    });
    return {
      demo: false,
      label: "Synced from the app",
      asOf: asOf,
      medicines: medicines,
      doses: doses,
      notes: [],
      alerts: alerts,
      familyOnly: { alertLabel: "Alert number stays on the phone" },
    };
  }

  function paintAlerts(list, alerts) {
    list.replaceChildren();
    if (!alerts.length) {
      var li = document.createElement("li");
      li.className = "qrow";
      var msg = document.createElement("div");
      msg.className = "msg";
      var title = document.createElement("b");
      title.textContent = "Nothing in the bay.";
      msg.append(title);
      li.append(msg);
      list.append(li);
      return;
    }
    alerts.forEach(function (item) {
      list.append(alertRow(KIND[item.kind] || item.kind, item));
    });
  }

  function bayBlock(alerts) {
    var section = document.createElement("section");
    section.className = "block";
    var h = document.createElement("h2");
    h.textContent = "Notification bay";
    section.append(h);
    var list = document.createElement("ul");
    list.className = "queue";
    section.append(list);
    paintAlerts(list, alerts || []);
    return section;
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

    var layout = document.getElementById("overview-layout");
    var showData = !(state.mode === "commercial" && !state.unlocked);
    if (layout) layout.classList.toggle("is-open", showData);

    panel.replaceChildren();
    if (data.label) panel.append(banner(data.label));
    panel.append(toggle(state, panel));

    if (state.mode === "commercial" && !state.unlocked) {
      panel.append(pinForm(state, panel));
      return;
    }

    panel.append(countBlock("Today", today, true));
    panel.append(bayBlock(data.alerts));
    if (!commercial) panel.append(countBlock("This week", week, false));
    var split = document.createElement("div");
    split.className = "split";
    split.append(missedBlock(commercial ? today : week), notesBlock(data.notes));
    panel.append(split);
    panel.append(scheduleBlock(data.medicines));
    if (!commercial) panel.append(familyBlock(data));
  }

  function toggle(state, panel) {
    var bar = document.createElement("div");
    bar.className = "segment";
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
    form.className = "qr-card sheet";
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
    submit.className = "btn";
    submit.textContent = "Open commercial view";
    var error = document.createElement("p");
    error.className = "error";
    error.setAttribute("role", "alert");
    var help = document.createElement("p");
    help.id = "pin-help";
    help.className = "muted";
    help.textContent =
      "The code is 1234. This page compares those digits. A real build checks the SHA-256 on the server.";
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

  function countBlock(title, rows, withDoses) {
    var section = document.createElement("section");
    section.className = "block";
    var head = document.createElement("div");
    head.className = "block-head";
    var h = document.createElement("h2");
    h.textContent = title;
    if (!withDoses) head.classList.add("summary");
    head.append(h, countList(rows));
    section.append(head);
    if (withDoses) {
      var queue = document.createElement("div");
      queue.className = "queue";
      rows.forEach(function (d) {
        queue.append(doseRow(d));
      });
      section.append(queue);
    }
    return section;
  }

  function countList(rows) {
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
      li.append(strong, document.createTextNode(status));
      ul.append(li);
    });
    return ul;
  }

  function doseRow(d) {
    return queueRow(d.medicine, d.time, d.status, d.status);
  }

  function queueRow(title, detail, pillText, pillClass) {
    var row = document.createElement("div");
    row.className = "qrow";
    var msg = document.createElement("div");
    msg.className = "msg";
    var name = document.createElement("b");
    name.textContent = title;
    var small = document.createElement("small");
    small.textContent = detail;
    msg.append(name, small);
    row.append(msg);
    if (pillText) {
      var status = document.createElement("span");
      status.className = "pill " + pillClass;
      status.textContent = pillText;
      row.append(status);
    }
    return row;
  }

  function alertRow(label, item) {
    var li = document.createElement("li");
    li.className = "qrow";
    var msg = document.createElement("div");
    msg.className = "msg";
    var title = document.createElement("b");
    title.textContent = label;
    msg.append(title);
    if (item.medicines && item.medicines.length) {
      item.medicines.forEach(function (med) {
        var line = document.createElement("div");
        line.className = "med-line";
        var name = document.createElement("span");
        name.textContent = med.name;
        line.append(name, pillMarks(med.pills));
        msg.append(line);
      });
    } else {
      var detail = document.createElement("small");
      detail.textContent = item.medicine ? item.medicine + " · " + item.time : item.time;
      msg.append(detail);
    }
    li.append(msg);
    if (item.kind === "missed_dose") li.classList.add("missed");
    return li;
  }

  function missedBlock(rows) {
    var section = document.createElement("section");
    section.className = "block";
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
    var queue = document.createElement("div");
    queue.className = "queue";
    missed.forEach(function (d) {
      queue.append(queueRow(d.medicine, d.time + " · " + d.day, "missed", "missed"));
    });
    section.append(queue);
    return section;
  }

  function notesBlock(notes) {
    var section = document.createElement("section");
    section.className = "block";
    var h = document.createElement("h2");
    h.textContent = "Notes";
    section.append(h);
    if (!notes || !notes.length) {
      var empty = document.createElement("p");
      empty.className = "muted";
      empty.textContent = "Notes stay on the phone.";
      section.append(empty);
      return section;
    }
    notes
      .slice()
      .sort(function (a, b) {
        return (RANK[a.priority] ?? 9) - (RANK[b.priority] ?? 9);
      })
      .forEach(function (note) {
        var p = document.createElement("p");
        p.className = "note" + (note.priority === "high" ? " note-high" : "");
        var pill = document.createElement("span");
        pill.className = "pill " + note.priority;
        pill.textContent = note.priority;
        p.append(pill, document.createTextNode(" " + note.text));
        section.append(p);
      });
    return section;
  }

  function scheduleBlock(medicines) {
    var section = document.createElement("section");
    section.className = "block";
    var h = document.createElement("h2");
    h.textContent = "Schedule";
    var queue = document.createElement("div");
    queue.className = "queue";
    medicines.forEach(function (med) {
      queue.append(queueRow(med.name, med.time));
    });
    section.append(h, queue);
    return section;
  }

  function familyBlock(data) {
    var section = document.createElement("section");
    section.className = "block";
    var h = document.createElement("h2");
    h.textContent = "For family";
    var alert = document.createElement("p");
    alert.className = "note";
    alert.textContent =
      (data.familyOnly && data.familyOnly.alertLabel) || "The phone keeps the records.";
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

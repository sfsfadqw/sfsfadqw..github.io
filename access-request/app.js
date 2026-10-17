// Access Request — поведение по §6, §8, §9 документации. Данные в localStorage.
const KEY = "access-requests-v1";
const $ = (id) => document.getElementById(id);

const seed = [
  { num: 1043, resource: "База данных клиентов", access: "Чтение", reason: "Нужен доступ для ежемесячной отчётности.", term: "3 месяца", created: "12.05.2025", status: "Новый" },
  { num: 1042, resource: "CRM (отдел продаж)", access: "Запись", reason: "Ведение сделок и обновление карточек клиентов.", term: "6 месяцев", created: "04.05.2025", status: "На согласовании" },
  { num: 1041, resource: "Хранилище отчётов", access: "Чтение", reason: "Подготовка квартального отчёта для руководства.", term: "Бессрочно", created: "28.04.2025", status: "Выполнен" },
];

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw);
  } catch { /* ignore */ }
  localStorage.setItem(KEY, JSON.stringify(seed));
  return [...seed];
}
let items = load();
let current = null;
function save() { localStorage.setItem(KEY, JSON.stringify(items)); }

function toast(text) {
  const t = document.createElement("div");
  t.className = "toast";
  t.textContent = text;
  $("toasts").appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

function badgeClass(s) {
  if (s === "Новый") return "b-Новый";
  if (s.startsWith("На")) return "b-На";
  if (s === "Одобрен") return "b-Одобрен";
  if (s === "Отклонён") return "b-Отклонён";
  return "b-Выполнен";
}

function show(name) {
  for (const v of ["list", "create", "detail", "help"]) {
    $("view-" + v).classList.toggle("hidden", v !== name);
  }
  document.querySelectorAll(".nav").forEach((b) => {
    b.classList.toggle("active", b.dataset.nav === (name === "detail" ? "list" : name));
  });
}

function renderList() {
  const box = $("cards");
  box.innerHTML = "";
  const empty = items.length === 0;
  $("empty").classList.toggle("hidden", !empty);
  for (const r of [...items].sort((a, b) => b.num - a.num)) {
    const c = document.createElement("button");
    c.className = "card";
    c.innerHTML = `<h3>Запрос №${r.num} <span class="badge ${badgeClass(r.status)}">${r.status}</span></h3>
      <p>${r.resource} • ${r.access} • ${r.term}</p><small>Создан: ${r.created}</small>`;
    c.onclick = () => openDetail(r.num);
    box.appendChild(c);
  }
}

function openDetail(num) {
  current = items.find((x) => x.num === num) || null;
  if (!current) return;
  $("d-title").textContent = "Запрос №" + current.num;
  const b = $("d-badge");
  b.textContent = current.status;
  b.className = "badge " + badgeClass(current.status);
  $("d-resource").textContent = current.resource;
  $("d-access").textContent = current.access;
  $("d-reason").textContent = current.reason;
  $("d-term").textContent = current.term;
  $("d-created").textContent = current.created;
  $("d-status").textContent = current.status;
  const box = $("d-actions");
  box.innerHTML = "";
  const mk = (label, cls, fn) => {
    const btn = document.createElement("button");
    btn.className = "btn " + cls;
    btn.textContent = label;
    btn.onclick = fn;
    box.appendChild(btn);
  };
  if (current.status === "Новый") {
    mk("Отправить на согласование", "primary", () => {
      current.status = "На согласовании"; save(); openDetail(current.num); renderList();
    });
  } else if (current.status === "На согласовании") {
    mk("Одобрить", "primary", () => {
      current.status = "Одобрен"; save(); openDetail(current.num); renderList();
    });
    mk("Отклонить", "danger", () => $("modal").classList.remove("hidden"));
  } else if (current.status === "Одобрен") {
    mk("Отметить выдачу доступа", "primary", () => {
      current.status = "Выполнен"; save(); openDetail(current.num); renderList();
    });
  }
  show("detail");
}

// Навигация
document.querySelectorAll(".nav").forEach((b) => {
  b.onclick = () => show(b.dataset.nav === "create" ? "create" : b.dataset.nav === "help" ? "help" : "list");
});
$("btn-create").onclick = () => show("create");
$("btn-first").onclick = () => show("create");
$("btn-cancel").onclick = () => show("list");
$("btn-back").onclick = () => { renderList(); show("list"); };

// Создание с валидацией + «Сохранение…» 1.5 c
$("form").addEventListener("submit", (e) => {
  e.preventDefault();
  const res = $("f-resource").value.trim();
  const reason = $("f-reason").value.trim();
  let ok = true;
  $("e-resource").classList.toggle("hidden", res !== "");
  $("f-resource").classList.toggle("bad", res === "");
  if (!res) ok = false;
  const reasonOk = reason.length >= 15;
  $("e-reason").classList.toggle("hidden", reasonOk);
  $("f-reason").classList.toggle("bad", !reasonOk);
  if (!reasonOk) ok = false;
  if (!ok) return; // запрос не создаётся (§9)

  const btn = $("btn-submit");
  btn.disabled = true;
  btn.textContent = "Сохранение…";
  setTimeout(() => {
    try {
      const next = Math.max(...items.map((x) => x.num), 1043) + 1;
      const today = new Date().toLocaleDateString("ru-RU");
      items.unshift({
        num: next,
        resource: res,
        access: $("f-access").value,
        reason,
        term: $("f-term").value,
        created: today,
        status: "Новый",
      });
      save();
      renderList();
      show("list");
      toast(`Запрос №${next} успешно создан.`);
      $("form").reset();
    } catch {
      toast("Не удалось сохранить запрос. Повторите попытку.");
    } finally {
      btn.disabled = false;
      btn.textContent = "Создать запрос";
    }
  }, 1500);
});

// Модалка отклонения
$("m-no").onclick = () => $("modal").classList.add("hidden");
$("m-yes").onclick = () => {
  if (current) {
    current.status = "Отклонён";
    save(); renderList(); openDetail(current.num);
  }
  $("modal").classList.add("hidden");
};

renderList();
show("list");

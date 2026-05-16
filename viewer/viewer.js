// Barry's Workflow viewer — v2.7.3
// Talks to viewer_server.py over /api/*. No static manifests.

const FSM_STATES = ["BOOT", "PREPARE", "REFLECT", "EXECUTE_LOOP", "RECORDING", "END"];
const REFRESH_INTERVAL_MS = 5000;

const S = {
  info: null,
  sessions: [],
  sid: null,
  sessionFiles: null,
  workspace: null,
  stateParsed: null,         // parsed YAML of state.md
  actionText: "",
  transitionsText: "",
  transcript: null,          // {events: [...]}
  agents: [],                // [{agentId, short_aid, description, prompt, ...}]
  agentsByAid: {},           // short_aid -> agent record (for transcript rewrite)
  selected: null,            // {kind, key} — what's open in content pane
  autoRefresh: true,
  refreshTimer: null,
  lastRefresh: 0,
  refreshTickerTimer: null,
  showTranscript: localStorage.getItem("showTranscript") !== "0",
};

const $ = id => document.getElementById(id);
function el(tag, attrs = {}, ...children) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k === "html") e.innerHTML = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (v != null) e.setAttribute(k, v);
  }
  for (const c of children) {
    if (c == null) continue;
    e.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
  }
  return e;
}
function esc(s) { return String(s ?? "").replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[c])); }

async function api(path, opts={}) {
  const r = await fetch(path, { cache: "no-store", ...opts });
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  const ct = r.headers.get("content-type") || "";
  return ct.includes("json") ? r.json() : r.text();
}

// ---------- bootstrap ----------
async function boot() {
  try {
    S.info = await api("/api/info");
  } catch (e) {
    $("content-body").innerHTML = `<div class="placeholder">Server unreachable: ${esc(e.message)}</div>`;
    return;
  }
  $("cwd-label").textContent = `cwd: ${S.info.cwd}` + (S.info.barry_exists ? "" : "  (no .barry_workflow/)");
  await reloadSessions();
  // pick session from URL or newest
  const urlSid = new URLSearchParams(location.search).get("sid");
  const initial = urlSid && S.sessions.find(s => s.sid === urlSid) ? urlSid
                : (S.sessions[0]?.sid || null);
  if (initial) await selectSession(initial);
  setAutoRefresh(S.autoRefresh);
  applyLayoutPrefs();
}

async function reloadSessions() {
  const r = await api("/api/sessions");
  S.sessions = r.sessions || [];
  renderSessionList();
}

// ---------- session picker (topbar dropdown) ----------
function renderSessionList() {
  const sel = $("session-select"); if (!sel) return;
  sel.innerHTML = "";
  if (!S.sessions.length) {
    const o = document.createElement("option");
    o.textContent = "(no sessions)"; o.disabled = true;
    sel.appendChild(o); return;
  }
  for (const s of S.sessions) {
    const o = document.createElement("option");
    o.value = s.sid;
    o.textContent = `${s.sid.slice(0,8)}  [${s.current_status || "?"}]`;
    if (s.sid === S.sid) o.selected = true;
    sel.appendChild(o);
  }
}

function renderStateStrip() {
  const strip = $("state-strip"); if (!strip) return;
  strip.innerHTML = "";
  if (!S.stateParsed) {
    strip.appendChild(el("div", { class: "placeholder", style: "grid-column: 1 / -1;" }, "(no session selected)"));
    return;
  }
  const current = S.stateParsed.current_status;
  const sh = S.stateParsed.stage_history || [];
  const ordered = [...sh].reverse();
  const visited = new Set([current]);
  for (const r of sh) if (r.to) visited.add(r.to);

  for (const st of FSM_STATES) {
    const enters = ordered.filter(r => r.to === st);
    const isVisited = visited.has(st);
    const isCur = st === current;
    const isSel = S.selected?.kind === "state" && S.selected.key === st;
    const tokens = computeStateTokens(st, ordered);
    const firstAt = enters[0]?.at || "";
    const lastAt = enters[enters.length - 1]?.at || "";
    const card = el("div", {
      class: [
        "ss-card", "s-" + st,
        isCur ? "current" : "",
        isSel ? "active" : "",
        !isVisited && !isCur ? "unvisited" : "",
      ].filter(Boolean).join(" "),
      title: st + (enters.length ? ` · ${enters.length} entry/entries` : " · not visited"),
      onclick: () => select({ kind: "state", key: st }),
    });
    card.appendChild(el("div", { class: "ss-name" }, st));
    card.appendChild(el("div", { class: "ss-pill" }, isCur ? "current" : (isVisited ? "seen" : "—")));
    const tShort = (x) => (x || "").slice(11, 19) || "—";
    card.appendChild(el("div", { class: "ss-meta" }, `${tShort(firstAt)} → ${tShort(lastAt)} · ${enters.length}× `));
    card.appendChild(el("div", { class: "ss-tokens" }, `in ${fmtN(tokens.input)} · out ${fmtN(tokens.output)} · ${tokens.events} msg`));
    strip.appendChild(card);
  }
}

function renderTransitionList() {
  const ul = $("transition-list"); ul.innerHTML = "";
  const sh = S.stateParsed?.stage_history || [];
  if (!sh.length) { ul.appendChild(el("li", { class: "dim" }, "(none)")); return; }
  // oldest first for "timeline" semantics
  const ordered = [...sh].reverse();
  ordered.forEach((r, i) => {
    const li = el("li", {
      class: (S.selected?.kind === "transition" && S.selected.key === String(i) ? "active" : ""),
      title: r.reason || "",
      onclick: () => select({ kind: "transition", key: String(i) }),
    },
      el("span", {}, `${r.event || "?"} → ${r.to || "?"}`),
      el("span", { class: "badge" }, (r.at || "").slice(11, 19) || "—"),
    );
    ul.appendChild(li);
  });
}

function renderLedgerList() {
  const ul = $("ledger-list"); ul.innerHTML = "";
  const led = S.workspace?.ledgers || [];
  if (!led.length) { ul.appendChild(el("li", { class: "dim" }, "(workspace/ empty)")); return; }
  for (const f of led) {
    const li = el("li", {
      class: (S.selected?.kind === "ledger" && S.selected.key === f.name ? "active" : ""),
      onclick: () => select({ kind: "ledger", key: f.name }),
    },
      el("span", {}, f.name),
      el("span", { class: "badge" }, fmtSize(f.size)),
    );
    ul.appendChild(li);
  }
}

function renderTaskList() {
  const ul = $("task-list"); ul.innerHTML = "";
  const tasks = S.workspace?.tasks || [];
  if (!tasks.length) { ul.appendChild(el("li", { class: "dim" }, "(no tasks)")); return; }
  for (const t of tasks) {
    const li = el("li", {
      class: (S.selected?.kind === "task" && S.selected.key === t.name ? "active" : ""),
      title: t.name,
      onclick: () => select({ kind: "task", key: t.name }),
    },
      el("span", {}, t.name),
      el("span", { class: "badge" }, "goal.md"),
    );
    ul.appendChild(li);
  }
}

function renderReflectionList() {
  const ul = $("reflection-list"); ul.innerHTML = "";
  const refs = S.sessionFiles?.reflections || [];
  if (!refs.length) { ul.appendChild(el("li", { class: "dim" }, "(none)")); return; }
  for (const f of refs) {
    const li = el("li", {
      class: (S.selected?.kind === "reflection" && S.selected.key === f ? "active" : ""),
      onclick: () => select({ kind: "reflection", key: f }),
    }, f.replace(/^reflection_/, "").replace(/\.md$/, ""));
    ul.appendChild(li);
  }
}

function renderRawList() {
  const ul = $("raw-list"); ul.innerHTML = "";
  if (!S.sid) { ul.appendChild(el("li", { class: "dim" }, "(no session)")); return; }
  const items = [
    { key: "state.md", label: "state.md" },
    { key: "action.md", label: "action.md" },
    { key: "transitions.log", label: "transitions.log" },
  ];
  for (const it of items) {
    const li = el("li", {
      class: (S.selected?.kind === "raw" && S.selected.key === it.key ? "active" : ""),
      onclick: () => select({ kind: "raw", key: it.key }),
    }, it.label);
    ul.appendChild(li);
  }
}

function fmtSize(n) {
  if (n == null) return "—";
  if (n < 1024) return n + "B";
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + "K";
  return (n / 1024 / 1024).toFixed(1) + "M";
}

// ---------- session select ----------
async function selectSession(sid) {
  S.sid = sid;
  const qs = new URLSearchParams(location.search); qs.set("sid", sid);
  history.replaceState(null, "", "?" + qs.toString());
  await Promise.all([loadSessionMeta(), loadWorkspace(), loadAgents()]);
  renderSessionList();
  renderStateStrip();
  renderTransitionList();
  renderLedgerList();
  renderTaskList();
  renderAgentList();
  renderReflectionList();
  renderRawList();
  // default selection: current state's panel
  if (!S.selected || S.selected.kind === "state" || S.selected.kind === "raw") {
    select({ kind: "state", key: S.stateParsed?.current_status || "END" });
  } else {
    refreshContent();
  }
  refreshTranscript();
}

async function loadSessionMeta() {
  try {
    const [stateText, actionText, transitionsText, files] = await Promise.all([
      api(`/api/file?sid=${S.sid}&path=state.md`).catch(() => ""),
      api(`/api/file?sid=${S.sid}&path=action.md`).catch(() => ""),
      api(`/api/file?sid=${S.sid}&path=transitions.log`).catch(() => ""),
      api(`/api/session_files?sid=${S.sid}`).catch(() => ({})),
    ]);
    S.actionText = actionText || "";
    S.transitionsText = transitionsText || "";
    S.sessionFiles = files || {};
    S.stateParsed = parseStateMd(stateText || "");
  } catch (e) {
    console.error(e);
  }
}

async function loadWorkspace() {
  try { S.workspace = await api("/api/workspace"); }
  catch { S.workspace = { ledgers: [], tasks: [] }; }
}

async function loadAgents() {
  try {
    const r = await api(`/api/agents?sid=${S.sid}`);
    S.agents = r.agents || [];
  } catch { S.agents = []; }
  S.agentsByAid = {};
  for (const a of S.agents) {
    if (a.short_aid) S.agentsByAid[a.short_aid] = a;
    if (a.agentId)   S.agentsByAid[a.agentId] = a;
  }
}

function renderAgentList() {
  const ul = $("agent-list"); ul.innerHTML = "";
  const cnt = $("agents-count"); if (cnt) cnt.textContent = S.agents.length ? `(${S.agents.length})` : "";
  if (!S.agents.length) { ul.appendChild(el("li", { class: "dim" }, "(no subagents)")); return; }
  for (const a of S.agents) {
    const label = a.description || a.subagent_type || "(no description)";
    const sub = (a.subagent_type || "?") + " · " + (a.short_aid || "");
    const li = el("li", {
      class: (S.selected?.kind === "agent" && S.selected.key === a.tool_use_id ? "active" : ""),
      title: a.prompt ? a.prompt.slice(0, 200) : "",
      onclick: () => select({ kind: "agent", key: a.tool_use_id }),
    },
      el("span", {}, label.slice(0, 40)),
      el("span", { class: "badge" }, a.status === "running" ? "live" : "done"),
    );
    li.appendChild(el("div", { class: "dim", style: "font-size:10px;width:100%;padding-left:0;margin-top:1px;color:var(--muted)" }, sub));
    ul.appendChild(li);
  }
}

function renderAgentDetail(tuId, title, meta, body) {
  const a = S.agents.find(x => x.tool_use_id === tuId);
  if (!a) { body.innerHTML = '<div class="placeholder">Unknown subagent.</div>'; return; }
  title.innerHTML = `Subagent: <span class="dim">${esc(a.description || a.subagent_type || a.short_aid)}</span>`;
  meta.innerHTML = `<span>${esc(a.started_at || "")}</span>`;
  body.innerHTML = "";
  const wrap = el("div", { class: "agent-detail" });
  function row(lbl, val, extraCls) {
    const r = el("div", { class: "ag-row" });
    r.appendChild(el("div", { class: "lbl" }, lbl));
    r.appendChild(el("div", { class: "val" + (extraCls ? " " + extraCls : "") }, String(val ?? "—")));
    return r;
  }
  wrap.appendChild(row("Description", a.description || "—"));
  wrap.appendChild(row("subagent_type", a.subagent_type || "—"));
  wrap.appendChild(row("agentId", a.agentId || "(not captured)"));
  wrap.appendChild(row("tool_use_id", a.tool_use_id));
  wrap.appendChild(row("Model", a.model || "(default)"));
  wrap.appendChild(row("Started", a.started_at || "—"));
  wrap.appendChild(row("Status", a.status, "status-" + a.status));
  wrap.appendChild(row("Sidechain msgs", String(a.sidechain_message_count ?? 0)));
  body.appendChild(wrap);

  body.appendChild(el("h3", {}, "Prompt"));
  const pre = el("div", { class: "agent-prompt" });
  pre.textContent = a.prompt || "(no prompt captured)";
  body.appendChild(pre);
}

// ---------- state.md YAML parse ----------
function parseStateMd(text) {
  const out = { current_status: null, prev_status: null, stage_history: [], inherited_from: null, raw: text };
  const m = text.match(/---YAML---\s*\n([\s\S]*?)\n---YAML---/);
  if (!m) return out;
  const body = m[1];
  const cs = body.match(/^current_status:\s*(\S+)/m); if (cs) out.current_status = cs[1];
  const ps = body.match(/^prev_status:\s*(\S+)/m); if (ps) out.prev_status = ps[1];
  const inh = body.match(/^inherited_from:\s*(\S+)/m); if (inh) out.inherited_from = inh[1];
  const sh = body.match(/^stage_history:\s*\n((?:[ \t].*\n)+)/m);
  if (sh) {
    for (const line of sh[1].split("\n")) {
      const mm = line.match(/^\s*-\s*\{(.+)\}\s*$/);
      if (!mm) continue;
      const o = {};
      // {event: BOOT_DONE, to: PREPARE, at: 2026-..., reason: "..."}
      const re = /(\w+):\s*("[^"]*"|[^,}]+)/g;
      let mp;
      while ((mp = re.exec(mm[1])) !== null) {
        o[mp[1]] = mp[2].replace(/^"|"$/g, "").trim();
      }
      out.stage_history.push(o);
    }
  }
  return out;
}

// ---------- content pane ----------
function select(sel) {
  S.selected = sel;
  // refresh active classes in lists
  renderStateStrip();
  renderTransitionList();
  renderLedgerList();
  renderTaskList();
  renderAgentList();
  renderReflectionList();
  renderRawList();
  refreshContent();
}

async function refreshContent() {
  if (!S.selected) return;
  const body = $("content-body");
  const title = $("content-title");
  const meta = $("content-meta");
  body.innerHTML = '<div class="placeholder">Loading…</div>';
  meta.innerHTML = "";
  const { kind, key } = S.selected;
  try {
    if (kind === "state") return renderStatePanel(key, title, meta, body);
    if (kind === "transition") return renderTransitionDetail(parseInt(key, 10), title, meta, body);
    if (kind === "agent") return renderAgentDetail(key, title, meta, body);
    if (kind === "ledger") {
      title.innerHTML = `Ledger: <span class="dim">workspace/${esc(key)}</span>`;
      const text = await api(`/api/workspace_file?path=${encodeURIComponent(key)}`);
      renderMd(body, text);
      return;
    }
    if (kind === "task") {
      title.innerHTML = `Task goal: <span class="dim">workspace/${esc(key)}/goal.md</span>`;
      const text = await api(`/api/workspace_file?path=${encodeURIComponent(key + "/goal.md")}`);
      renderMd(body, text);
      return;
    }
    if (kind === "reflection") {
      title.innerHTML = `Reflection: <span class="dim">${esc(key)}</span>`;
      const text = await api(`/api/file?sid=${S.sid}&path=${encodeURIComponent(key)}`);
      renderMd(body, text);
      return;
    }
    if (kind === "raw") {
      title.innerHTML = `Raw: <span class="dim">${esc(key)}</span>`;
      const text = await api(`/api/file?sid=${S.sid}&path=${encodeURIComponent(key)}`);
      if (key === "transitions.log") {
        body.innerHTML = "";
        body.appendChild(el("pre", { class: "md" }, text));
      } else {
        renderMd(body, text);
      }
      return;
    }
    body.innerHTML = '<div class="placeholder">Unknown selection.</div>';
  } catch (e) {
    body.innerHTML = `<div class="placeholder">Error: ${esc(e.message)}</div>`;
  }
}

function katexRender(node) {
  if (!node || typeof window === "undefined" || !window.renderMathInElement) return;
  try {
    window.renderMathInElement(node, {
      delimiters: [
        { left: "$$", right: "$$", display: true },
        { left: "\\[", right: "\\]", display: true },
        { left: "$",  right: "$",  display: false },
        { left: "\\(", right: "\\)", display: false },
      ],
      throwOnError: false,
      ignoredTags: ["script", "noscript", "style", "textarea", "pre", "code"],
    });
  } catch (e) { /* swallow */ }
}

function renderMd(body, text) {
  body.innerHTML = "";
  const div = el("div", { class: "md" });
  div.innerHTML = marked.parse(text || "");
  body.appendChild(div);
  katexRender(div);
}

// ---------- state panel ----------
function renderStatePanel(stateName, title, meta, body) {
  if (!S.stateParsed) { body.innerHTML = '<div class="placeholder">No state data.</div>'; return; }
  title.innerHTML = `State: <span class="dim">${esc(stateName)}</span>`;
  meta.innerHTML = `<span>session ${S.sid?.slice(0, 8)}</span>`;

  // Find entries in stage_history that *entered* this state.
  const sh = S.stateParsed.stage_history || []; // newest first in our parse
  // Re-sort oldest-first for chronological reasoning.
  const ordered = [...sh].reverse();
  const enters = ordered.filter(r => r.to === stateName);
  const tokenUsage = computeStateTokens(stateName, ordered);
  const actionSlice = sliceActionMdByState(stateName, ordered);

  body.innerHTML = "";

  // summary cards
  const wrap = el("div", { class: "state-summary" });
  const firstEnter = enters[0]?.at || "—";
  const lastEnter = enters[enters.length - 1]?.at || "—";
  wrap.appendChild(card("State", stateName, S.stateParsed.current_status === stateName ? "currently active" : (enters.length ? `visited ${enters.length}×` : "not visited")));
  wrap.appendChild(card("First entry", firstEnter, enters[0]?.event || ""));
  wrap.appendChild(card("Last entry", lastEnter, enters[enters.length - 1]?.event || ""));
  wrap.appendChild(card("Input tokens", fmtN(tokenUsage.input), `cache R: ${fmtN(tokenUsage.cache_read)} · C: ${fmtN(tokenUsage.cache_create)}`));
  wrap.appendChild(card("Output tokens", fmtN(tokenUsage.output), `${tokenUsage.events} message(s)`));
  body.appendChild(wrap);

  // action.md slice
  const aH = el("h3", {}, `action.md (${actionSlice.length} line(s) attributed to ${stateName})`);
  body.appendChild(aH);
  if (actionSlice.length) {
    const pre = el("div", { class: "md" });
    pre.innerHTML = marked.parse("```\n" + actionSlice.join("\n") + "\n```");
    body.appendChild(pre);
    katexRender(pre);
  } else {
    body.appendChild(el("div", { class: "placeholder" }, "No action.md lines attributed to this state (action.md uses transition markers like [BOOT_DONE], [PREPARE_DONE]…)."));
  }

  // reflections matching this state (best-effort — REFLECT state)
  if (stateName === "REFLECT") {
    const refs = S.sessionFiles?.reflections || [];
    if (refs.length) {
      body.appendChild(el("h3", {}, `Reflection files (${refs.length})`));
      const ul = el("ul");
      for (const f of refs) {
        const li = el("li");
        li.appendChild(el("a", { href: "#", onclick: e => { e.preventDefault(); select({ kind: "reflection", key: f }); } }, f));
        ul.appendChild(li);
      }
      body.appendChild(ul);
    }
  }
}

function card(lbl, val, sub) {
  const c = el("div", { class: "state-card" });
  c.appendChild(el("div", { class: "lbl" }, lbl));
  c.appendChild(el("div", { class: "val" }, String(val)));
  if (sub) c.appendChild(el("div", { class: "sub" }, sub));
  return c;
}

function fmtN(n) {
  if (n == null || n === 0) return "0";
  if (n >= 1000) return (n / 1000).toFixed(1) + "k";
  return String(n);
}

// ---------- per-state token accounting ----------
function computeStateTokens(stateName, orderedHistory) {
  const out = { input: 0, output: 0, cache_read: 0, cache_create: 0, events: 0 };
  if (!S.transcript?.events?.length) return out;
  // Build intervals: each entry in orderedHistory says "at this ts, we transitioned to .to".
  // For state X, intervals = [t_enter_i, t_exit_i] where exit is the next transition.at.
  const intervals = [];
  let curState = null, curStart = null;
  for (const r of orderedHistory) {
    if (curState != null) intervals.push({ state: curState, start: curStart, end: r.at });
    curState = r.to;
    curStart = r.at;
  }
  if (curState != null) intervals.push({ state: curState, start: curStart, end: null });
  const mine = intervals.filter(i => i.state === stateName);
  if (!mine.length) return out;
  for (const ev of S.transcript.events) {
    if (!ev.ts) continue;
    const inAny = mine.some(i => ev.ts >= i.start && (i.end == null || ev.ts < i.end));
    if (!inAny) continue;
    out.events += 1;
    const u = ev.usage || {};
    out.input        += u.input_tokens || 0;
    out.output       += u.output_tokens || 0;
    out.cache_read   += u.cache_read_input_tokens || 0;
    out.cache_create += u.cache_creation_input_tokens || 0;
  }
  return out;
}

// ---------- action.md slice ----------
function sliceActionMdByState(stateName, orderedHistory) {
  // action.md is appended with markers like [BOOT_DONE] [PREPARE_DONE] etc.
  // Approach: split action.md on lines containing any transition event token.
  // Each segment is attributed to the state that was *active* at the time
  // the next-segment-marker fired — i.e. segment between transition[i-1] and
  // transition[i] belongs to transition[i-1].to.
  const lines = (S.actionText || "").split(/\r?\n/);
  // Find marker line indices.
  const markerEvents = ["BOOT_DONE", "PREPARE_DONE", "REFLECT_DONE", "EXECUTE_EXIT",
                        "NEED_RECORD", "RECORD_DONE", "BACK_TO_LOOP", "RESET_TO_BOOT"];
  const markerIdxs = [];
  lines.forEach((ln, i) => {
    for (const ev of markerEvents) {
      if (ln.includes(`[${ev}`) || ln.includes(`${ev} @`) || ln.match(new RegExp(`\\b${ev}\\b.*@`))) {
        markerIdxs.push({ idx: i, ev });
        break;
      }
    }
  });
  // Segments: [0..m0), [m0..m1), ...
  const segs = [];
  let prev = 0, prevEv = null;
  for (const m of markerIdxs) {
    segs.push({ from: prev, to: m.idx, prevEv });
    prev = m.idx;
    prevEv = m.ev;
  }
  segs.push({ from: prev, to: lines.length, prevEv });

  // Map segment → which state was active.
  // We walk orderedHistory in parallel: each transition.event in markerEvents
  // moves us into transition.to. The segment AFTER a marker belongs to
  // transition.to. The first segment (before any marker) belongs to BOOT.
  let active = "BOOT";
  let mIdx = 0;
  const out = [];
  for (const seg of segs) {
    if (active === stateName) {
      for (let i = seg.from; i < seg.to; i++) out.push(lines[i]);
    }
    if (seg.prevEv) {
      // Advance active state per the corresponding transition in history.
      const tr = orderedHistory[mIdx];
      if (tr && tr.event === seg.prevEv && tr.to) active = tr.to;
      else if (tr) active = tr.to || active;
      mIdx++;
    }
  }
  // Trim leading empties
  while (out.length && !out[0].trim()) out.shift();
  while (out.length && !out[out.length - 1].trim()) out.pop();
  return out;
}

// ---------- transition detail ----------
function renderTransitionDetail(i, title, meta, body) {
  const sh = S.stateParsed?.stage_history || [];
  const ordered = [...sh].reverse();
  const r = ordered[i];
  if (!r) { body.innerHTML = '<div class="placeholder">Unknown transition.</div>'; return; }
  title.innerHTML = `Transition #${i + 1}: <span class="dim">${esc(r.event || "?")} → ${esc(r.to || "?")}</span>`;
  meta.innerHTML = `<span>${esc(r.at || "")}</span>`;
  body.innerHTML = "";
  // Full timeline
  const ul = el("ul", { class: "timeline" });
  ordered.forEach((rr, ii) => {
    const li = el("li", {
      onclick: () => select({ kind: "transition", key: String(ii) }),
    });
    li.appendChild(el("span", { class: "ts" }, rr.at || ""));
    li.appendChild(el("span", { class: "event" }, rr.event || "?"));
    li.appendChild(el("span", { class: "arrow" }, "→"));
    li.appendChild(el("span", {}, rr.to || "?"));
    if (rr.reason) li.appendChild(el("span", { class: "reason" }, rr.reason));
    if (ii === i) li.style.background = "var(--panel-2)";
    ul.appendChild(li);
  });
  body.appendChild(ul);
}

// ---------- transcript ----------
async function refreshTranscript() {
  const body = $("transcript-body");
  if (!S.sid) { body.innerHTML = '<div class="placeholder">No session selected.</div>'; return; }
  body.innerHTML = '<div class="placeholder">Loading transcript…</div>';
  try {
    S.transcript = await api(`/api/transcript?sid=${S.sid}`);
  } catch (e) {
    body.innerHTML = `<div class="placeholder">Transcript error: ${esc(e.message)}</div>`;
    return;
  }
  if (!S.transcript.exists) {
    body.innerHTML = `<div class="placeholder">No JSONL transcript at ${esc(S.transcript.path || "?")}</div>`;
    return;
  }
  const evs = S.transcript.events || [];
  $("transcript-count").textContent = `${evs.length} event(s) — newest first`;
  body.innerHTML = "";
  // Render newest-first.
  const ordered = [...evs].reverse();
  for (const ev of ordered) body.appendChild(renderBlock(ev));
  bindTranscriptFilters();
  applyTranscriptFilters();
  // refresh per-state tokens if a state panel is showing
  if (S.selected?.kind === "state") refreshContent();
}

function looksLikeMarkdown(text) {
  if (!text) return false;
  let hits = 0;
  if (/^#{1,6} /m.test(text))          hits++;
  if (/```/.test(text))                 hits++;
  if (/^\* /m.test(text))              hits++;
  if (/^\d+\. /m.test(text))           hits++;
  if (/\*\*[^*\n]+\*\*/.test(text))    hits++;
  if (/^\| /m.test(text))              hits++;
  if (/^> /m.test(text))               hits++;
  if (/\$\$|\\\(/.test(text))          hits++;
  return hits >= 2;
}

function renderBlock(ev) {
  const div = el("div", { class: `tr-block role-${ev.role || "system"}` });
  div.dataset.role = ev.role || "system";
  div.dataset.text = (ev.text || "").toLowerCase();
  const tag = ev.role + (ev.tool ? ` · ${ev.tool}` : "");
  const head = el("div", { class: "tr-head" },
    el("span", {}, tag),
    el("span", { class: "ts" }, ev.ts || ""),
  );
  div.appendChild(head);
  const text = (ev.text || "").slice(0, 6000);
  if (looksLikeMarkdown(text)) {
    const mdDiv = el("div", { class: "tr-md" });
    mdDiv.innerHTML = marked.parse(text);
    div.appendChild(mdDiv);
    katexRender(mdDiv);
  } else {
    const pre = el("pre");
    pre.textContent = text;
    div.appendChild(pre);
  }
  return div;
}

function bindTranscriptFilters() {
  if (bindTranscriptFilters._bound) return;
  bindTranscriptFilters._bound = true;
  $("filter-tools").addEventListener("change", applyTranscriptFilters);
  $("hide-reminders").addEventListener("change", applyTranscriptFilters);
  $("search-input").addEventListener("input", applyTranscriptFilters);
}

function applyTranscriptFilters() {
  const toolsOnly = $("filter-tools").checked;
  const hideRem = $("hide-reminders").checked;
  const q = $("search-input").value.trim().toLowerCase();
  for (const b of document.querySelectorAll(".tr-block")) {
    const role = b.dataset.role;
    let hide = false;
    if (toolsOnly && role !== "tool_use" && role !== "tool_result") hide = true;
    if (hideRem && b.dataset.text.includes("<system-reminder>")) hide = true;
    if (q && !b.dataset.text.includes(q)) hide = true;
    b.classList.toggle("tr-hide", hide);
    b.classList.toggle("tr-hl", !!q && !hide && b.dataset.text.includes(q));
  }
}

// ---------- auto-refresh ----------
function setAutoRefresh(on) {
  S.autoRefresh = on;
  if (S.refreshTimer) { clearInterval(S.refreshTimer); S.refreshTimer = null; }
  if (on) {
    S.refreshTimer = setInterval(liveTick, REFRESH_INTERVAL_MS);
  }
  if (!S.refreshTickerTimer) {
    S.refreshTickerTimer = setInterval(updateRefreshStatus, 1000);
  }
}

async function liveTick() {
  if (!S.autoRefresh || !S.sid) return;
  try {
    // Only refresh the currently visible thing.
    const sel = S.selected;
    if (!sel) return;
    if (sel.kind === "state" || sel.kind === "transition" || sel.kind === "raw") {
      // need state.md / action.md / transitions.log fresh
      const [stateText, actionText, transitionsText] = await Promise.all([
        api(`/api/file?sid=${S.sid}&path=state.md`).catch(() => S.stateParsed?.raw || ""),
        api(`/api/file?sid=${S.sid}&path=action.md`).catch(() => S.actionText),
        api(`/api/file?sid=${S.sid}&path=transitions.log`).catch(() => S.transitionsText),
      ]);
      const newParsed = parseStateMd(stateText);
      const changed = (stateText !== (S.stateParsed?.raw || "")) ||
                      (actionText !== S.actionText) ||
                      (transitionsText !== S.transitionsText);
      S.stateParsed = newParsed;
      S.actionText = actionText;
      S.transitionsText = transitionsText;
      if (changed) {
        renderStateStrip(); renderTransitionList();
        refreshContent();
      }
    } else if (sel.kind === "ledger" || sel.kind === "task" || sel.kind === "reflection") {
      // re-fetch and re-render
      refreshContent();
    }
    S.lastRefresh = Date.now();
    setRefreshStatus("live");
  } catch (e) {
    setRefreshStatus("err", e.message);
  }
}

function setRefreshStatus(kind, msg) {
  const el = $("refresh-status");
  if (!el) return;
  el.classList.remove("live", "stale", "err");
  el.classList.add(kind);
  el.dataset.msg = msg || "";
}

function updateRefreshStatus() {
  if (!S.autoRefresh) { $("refresh-status").textContent = "off"; return; }
  if (!S.lastRefresh) { $("refresh-status").textContent = "—"; return; }
  const age = Math.round((Date.now() - S.lastRefresh) / 1000);
  $("refresh-status").textContent = `last refresh ${age}s ago`;
  if (age > 15) $("refresh-status").classList.add("stale");
  else $("refresh-status").classList.remove("stale");
}

// ---------- layout: resize + hide ----------
function applyLayoutPrefs() {
  const navW = localStorage.getItem("navW");
  const trH  = localStorage.getItem("trH");
  const navTopPct = localStorage.getItem("navTopPct");
  if (navW) document.body.style.setProperty("--nav-w", navW + "px");
  if (trH)  document.body.style.setProperty("--tr-h",  trH  + "px");
  if (navTopPct) document.body.style.setProperty("--nav-top-h", navTopPct + "%");
  $("layout").classList.toggle("no-transcript", !S.showTranscript);
  $("toggle-transcript").classList.toggle("active", S.showTranscript);
  bindResizers();
}

function bindResizers() {
  const rh = $("resize-nav");
  const rv = $("resize-transcript");
  const rs = $("resize-vsplit");
  let dragging = null;
  function start(e, kind) {
    dragging = kind;
    document.body.style.cursor = (kind === "h" ? "col-resize" : "row-resize");
    e.preventDefault();
  }
  rh.addEventListener("mousedown", e => start(e, "h"));
  rv.addEventListener("mousedown", e => start(e, "v"));
  if (rs) rs.addEventListener("mousedown", e => start(e, "s"));
  window.addEventListener("mousemove", e => {
    if (!dragging) return;
    if (dragging === "h") {
      const w = Math.max(140, Math.min(window.innerWidth - 300, e.clientX));
      document.body.style.setProperty("--nav-w", w + "px");
      localStorage.setItem("navW", w);
    } else if (dragging === "v") {
      const h = Math.max(80, Math.min(window.innerHeight - 200, window.innerHeight - e.clientY));
      document.body.style.setProperty("--tr-h", h + "px");
      localStorage.setItem("trH", h);
    } else if (dragging === "s") {
      const nav = $("col-nav");
      const rect = nav.getBoundingClientRect();
      const pct = Math.max(15, Math.min(85, ((e.clientY - rect.top) / rect.height) * 100));
      document.body.style.setProperty("--nav-top-h", pct + "%");
      localStorage.setItem("navTopPct", pct.toFixed(1));
    }
  });
  window.addEventListener("mouseup", () => { dragging = null; document.body.style.cursor = ""; });

  $("toggle-transcript").addEventListener("click", () => {
    S.showTranscript = !S.showTranscript;
    localStorage.setItem("showTranscript", S.showTranscript ? "1" : "0");
    $("layout").classList.toggle("no-transcript", !S.showTranscript);
    $("toggle-transcript").classList.toggle("active", S.showTranscript);
  });
}

// ---------- init ----------
document.addEventListener("DOMContentLoaded", () => {
  if (window.marked && typeof marked.setOptions === "function") {
    marked.setOptions({ gfm: true, breaks: false, headerIds: false, mangle: false });
  }
  const cb = $("auto-refresh");
  cb.checked = S.autoRefresh;
  cb.addEventListener("change", e => setAutoRefresh(e.target.checked));
  const ss = $("session-select");
  if (ss) ss.addEventListener("change", e => { if (e.target.value) selectSession(e.target.value); });
  boot();
});

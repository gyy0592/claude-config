// Barry's Workflow — Session viewer
// Loads viewer/data/<sid>/manifest.json then renders agent tree, state, transcript.

const FSM_STATES = ["BOOT", "PREPARE", "REFLECT", "EXECUTE_LOOP", "RECORDING", "END"];

const state = {
  sid: null,
  manifest: null,
  selectedAgent: "main",
  stateTab: "state",
  selectedReflection: null,
  fileCache: new Map(),
};

function $(id) { return document.getElementById(id); }
function el(tag, attrs = {}, ...children) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k === "html") e.innerHTML = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v);
  }
  for (const c of children) {
    if (c == null) continue;
    e.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
  }
  return e;
}

async function fetchText(path) {
  if (state.fileCache.has(path)) return state.fileCache.get(path);
  const r = await fetch(path);
  if (!r.ok) throw new Error(`fetch ${path}: ${r.status}`);
  const t = await r.text();
  state.fileCache.set(path, t);
  return t;
}

async function fetchJSON(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error(`fetch ${path}: ${r.status}`);
  return r.json();
}

// ---------- Session index ----------
async function loadSessionIndex() {
  try {
    const idx = await fetchJSON("data/index.json");
    const sel = $("session-select");
    sel.innerHTML = "";
    for (const s of idx.sessions) {
      const opt = document.createElement("option");
      opt.value = s.sid;
      opt.textContent = s.label || s.sid;
      sel.appendChild(opt);
    }
    sel.addEventListener("change", () => loadSession(sel.value));
    const urlSid = new URLSearchParams(location.search).get("sid");
    const initial = urlSid && idx.sessions.find(s => s.sid === urlSid) ? urlSid : idx.sessions[0].sid;
    sel.value = initial;
    await loadSession(initial);
  } catch (e) {
    $("state-body").innerHTML = `<div class="placeholder">Failed to load data/index.json: ${e.message}</div>`;
  }
}

async function loadSession(sid) {
  state.sid = sid;
  state.fileCache.clear();
  $("sid-label").textContent = sid;
  const params = new URLSearchParams(location.search);
  state.selectedAgent = params.get("agent") || "main";
  state.stateTab = params.get("tab") || state.stateTab;
  const newQs = new URLSearchParams();
  newQs.set("sid", sid);
  if (state.selectedAgent !== "main") newQs.set("agent", state.selectedAgent);
  if (state.stateTab !== "state") newQs.set("tab", state.stateTab);
  history.replaceState(null, "", "?" + newQs.toString());
  const manifest = await fetchJSON(`data/${sid}/manifest.json`);
  state.manifest = manifest;
  state.selectedReflection = (manifest.main.reflections || [])[0] || null;
  renderSidebar();
  renderStatePane();
  renderTranscriptPane();
}

// ---------- Sidebar ----------
function renderSidebar() {
  const ul = $("agent-tree");
  ul.innerHTML = "";
  const m = state.manifest;

  ul.appendChild(el("li", {
    class: "main" + (state.selectedAgent === "main" ? " active" : ""),
    onclick: () => { state.selectedAgent = "main"; renderSidebar(); renderStatePane(); renderTranscriptPane(); }
  },
    el("span", { class: "icon" }),
    el("span", {}, "main"),
    el("span", { class: "badge" }, shortSid(m.sid))
  ));

  for (const sa of m.subagents) {
    const label = `agent_${sa.aid.slice(0, 8)}`;
    let badge = "agent";
    if (sa.kind === "ledger-only") badge = "ledger";
    else if (sa.kind === "jsonl-extract") badge = "jsonl";
    ul.appendChild(el("li", {
      class: "sub" + (state.selectedAgent === sa.aid ? " active" : ""),
      onclick: () => { state.selectedAgent = sa.aid; renderSidebar(); renderStatePane(); renderTranscriptPane(); }
    },
      el("span", { class: "icon" }),
      el("span", {}, label),
      el("span", { class: "badge" }, badge)
    ));
  }

  if (m.subagents.length === 0) {
    ul.appendChild(el("li", { class: "sub" }, el("span", { class: "icon", style: "background:#ccc" }), el("span", { style: "color:var(--muted);font-style:italic" }, "(no subagents)")));
  }
}

function shortSid(sid) { return sid.slice(0, 8); }

// ---------- State pane ----------
function renderStatePane() {
  // bind tabs once
  if (!renderStatePane._bound) {
    for (const btn of document.querySelectorAll("#state-tabs .tab")) {
      btn.addEventListener("click", () => {
        state.stateTab = btn.dataset.tab;
        renderStatePane();
      });
    }
    renderStatePane._bound = true;
  }
  for (const btn of document.querySelectorAll("#state-tabs .tab")) {
    btn.classList.toggle("active", btn.dataset.tab === state.stateTab);
  }

  const body = $("state-body");
  body.innerHTML = "";
  const meta = $("state-meta");
  meta.innerHTML = "";

  const isMain = state.selectedAgent === "main";
  const m = state.manifest;

  if (isMain) {
    if (state.stateTab === "state") renderStateTab(body, meta, m.main.state_path);
    else if (state.stateTab === "action") renderActionTab(body, meta, m.main.action_path);
    else if (state.stateTab === "reflections") renderReflectionsTab(body, meta, m.main.reflections);
  } else {
    const sa = m.subagents.find(s => s.aid === state.selectedAgent);
    if (!sa) { body.innerHTML = '<div class="placeholder">No data.</div>'; return; }
    if (state.stateTab === "state") {
      if (sa.state_path) renderStateTab(body, meta, sa.state_path);
      else {
        body.innerHTML = '<div class="placeholder">No state.md for this subagent — workflow did not create an agent_'+sa.aid+'/ subdir. Only the ledger is available (see action.md tab).</div>';
      }
    } else if (state.stateTab === "action") {
      renderActionTab(body, meta, sa.action_path);
    } else if (state.stateTab === "reflections") {
      body.innerHTML = '<div class="placeholder">Reflections are tracked at the main level.</div>';
    }
  }
}

async function renderStateTab(body, meta, statePath) {
  if (!statePath) { body.innerHTML = '<div class="placeholder">No state file.</div>'; return; }
  try {
    const text = await fetchText(`data/${state.sid}/${statePath}`);
    const parsed = parseStateYAML(text);

    if (parsed) {
      const current = parsed.current_status || "?";
      meta.innerHTML = `<span class="status-chip status-${current}">${current}</span><span class="dim" style="font-family:var(--mono);font-size:11.5px;color:var(--muted);">${statePath}</span>`;

      const wrap = el("div");
      // Metrics bar (per-state duration + token usage, from manifest.metrics).
      const metricsBar = buildMetricsBar();
      if (metricsBar) wrap.appendChild(metricsBar);
      wrap.appendChild(buildTimeline(current, parsed.stage_history || []));

      // stage history table
      if (parsed.stage_history && parsed.stage_history.length) {
        const det = el("details", { class: "collapsible" });
        det.appendChild(el("summary", {}, `stage_history (${parsed.stage_history.length} transitions)`));
        const tbl = el("table");
        tbl.style.cssText = "width:100%;border-collapse:collapse;font-size:12px;font-family:var(--mono);margin-top:8px;";
        tbl.innerHTML = "<thead><tr><th style='text-align:left;padding:4px 6px;border-bottom:1px solid var(--border-soft)'>at</th><th style='text-align:left;padding:4px 6px;border-bottom:1px solid var(--border-soft)'>event</th><th style='text-align:left;padding:4px 6px;border-bottom:1px solid var(--border-soft)'>→ to</th><th style='text-align:left;padding:4px 6px;border-bottom:1px solid var(--border-soft)'>reason</th></tr></thead>";
        const tb = el("tbody");
        for (const r of parsed.stage_history) {
          const tr = el("tr");
          tr.innerHTML = `<td style="padding:3px 6px;color:var(--muted)">${esc(r.at||'')}</td><td style="padding:3px 6px"><b>${esc(r.event||'')}</b></td><td style="padding:3px 6px;color:var(--accent)">${esc(r.to||'')}</td><td style="padding:3px 6px">${esc(r.reason||'')}</td>`;
          tb.appendChild(tr);
        }
        tbl.appendChild(tb);
        det.appendChild(tbl);
        wrap.appendChild(det);
      }

      // cache_hit_map collapsible
      if (parsed.cache_hit_map_raw) {
        const det = el("details", { class: "collapsible" });
        det.appendChild(el("summary", {}, "cache_hit_map"));
        det.appendChild(el("pre", {}, parsed.cache_hit_map_raw));
        wrap.appendChild(det);
      }

      // raw YAML collapsible
      const det2 = el("details", { class: "collapsible" });
      det2.appendChild(el("summary", {}, "raw state.md"));
      const md = el("div", { class: "md" });
      md.innerHTML = marked.parse(text);
      det2.appendChild(md);
      wrap.appendChild(det2);

      body.appendChild(wrap);
    } else {
      meta.innerHTML = `<span style="font-family:var(--mono);font-size:11.5px;color:var(--muted);">${statePath}</span>`;
      const md = el("div", { class: "md" });
      md.innerHTML = marked.parse(text);
      body.appendChild(md);
    }
  } catch (e) {
    body.innerHTML = `<div class="placeholder">Error: ${e.message}</div>`;
  }
}

async function renderActionTab(body, meta, actionPath) {
  if (!actionPath) { body.innerHTML = '<div class="placeholder">No action file.</div>'; return; }
  try {
    const text = await fetchText(`data/${state.sid}/${actionPath}`);
    // Take tail ~200 lines for readability but include "Show full" toggle
    const lines = text.split(/\r?\n/);
    const TAIL = 200;
    const tailText = lines.length > TAIL ? lines.slice(-TAIL).join("\n") : text;
    meta.innerHTML = `<span style="font-family:var(--mono);font-size:11.5px;color:var(--muted);">${actionPath} — ${lines.length} lines</span>`;

    if (lines.length > TAIL) {
      const det = el("details", { class: "collapsible" });
      det.appendChild(el("summary", {}, `full file (${lines.length} lines)`));
      const md = el("div", { class: "md" });
      md.innerHTML = marked.parse(text);
      det.appendChild(md);
      body.appendChild(det);
    }
    const heading = el("div", { class: "md" });
    heading.innerHTML = `<h3>tail (${Math.min(TAIL, lines.length)} lines)</h3>` + marked.parse(tailText);
    body.appendChild(heading);
  } catch (e) {
    body.innerHTML = `<div class="placeholder">Error: ${e.message}</div>`;
  }
}

async function renderReflectionsTab(body, meta, reflections) {
  if (!reflections || reflections.length === 0) {
    body.innerHTML = '<div class="placeholder">No reflection files for this session.</div>';
    return;
  }
  if (!state.selectedReflection || !reflections.includes(state.selectedReflection)) {
    state.selectedReflection = reflections[0];
  }
  meta.innerHTML = `<span style="font-family:var(--mono);font-size:11.5px;color:var(--muted);">${reflections.length} reflection file(s)</span>`;
  const tabs = el("div", { class: "refl-tabs" });
  for (const f of reflections) {
    const label = f.replace(/^reflection_/, "").replace(/\.md$/, "");
    const b = el("button", {
      class: f === state.selectedReflection ? "active" : "",
      onclick: () => { state.selectedReflection = f; renderStatePane(); }
    }, label);
    tabs.appendChild(b);
  }
  body.appendChild(tabs);
  try {
    const text = await fetchText(`data/${state.sid}/${state.selectedReflection}`);
    const md = el("div", { class: "md" });
    md.innerHTML = marked.parse(text);
    body.appendChild(md);
  } catch (e) {
    body.appendChild(el("div", { class: "placeholder" }, "Error: " + e.message));
  }
}

// ---------- State YAML parsing ----------
function parseStateYAML(text) {
  // Find the ---YAML--- block (custom marker) or yaml code fence
  const m = text.match(/---YAML---([\s\S]*?)---YAML---/);
  const body = m ? m[1] : (text.match(/```yaml([\s\S]*?)```/) || [])[1];
  if (!body) return null;
  const out = { stage_history: [], cache_hit_map_raw: null };
  // current_status
  const cs = body.match(/^current_status:\s*(\S+)/m);
  if (cs) out.current_status = cs[1];
  // stage_history
  const sh = body.match(/^stage_history:\s*\n([\s\S]*?)(?=\n[a-z_]+:|\Z)/m);
  if (sh) {
    for (const line of sh[1].split("\n")) {
      const mm = line.match(/^\s*-\s*\{(.+)\}\s*$/);
      if (mm) {
        const o = {};
        for (const kv of mm[1].split(/,\s*/)) {
          const p = kv.match(/^(\w+):\s*"?([^",]+)"?$/);
          if (p) o[p[1]] = p[2];
        }
        out.stage_history.push(o);
      }
    }
  }
  // cache_hit_map raw
  const cm = body.match(/^cache_hit_map:\s*\n([\s\S]*?)(?=\n[a-z_]+:|\Z)/m);
  if (cm) out.cache_hit_map_raw = cm[1].trimEnd();
  return out;
}

function fmtDuration(s) {
  if (s == null || s < 0) return "—";
  if (s < 60) return s + "s";
  const m = Math.floor(s / 60), r = s % 60;
  if (m < 60) return r ? `${m}m${r}s` : `${m}m`;
  const h = Math.floor(m / 60), rm = m % 60;
  return rm ? `${h}h${rm}m` : `${h}h`;
}

function fmtTokens(n) {
  if (n == null) return "—";
  if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k";
  return String(n);
}

function buildMetricsBar() {
  const metrics = state.manifest?.metrics;
  if (!metrics || !metrics.per_state || metrics.per_state.length === 0) return null;
  // Aggregate by state name (in case of multi-visit, sum durations + tokens).
  const agg = {};
  for (const r of metrics.per_state) {
    const a = agg[r.state] = agg[r.state] || { seconds: 0, in: 0, out: 0, cache_r: 0, cache_c: 0, turns: 0 };
    if (r.seconds != null) a.seconds += r.seconds;
    a.in      += r.tok_input_tokens             || 0;
    a.out     += r.tok_output_tokens            || 0;
    a.cache_r += r.tok_cache_read_input_tokens  || 0;
    a.cache_c += r.tok_cache_creation_input_tokens || 0;
    a.turns   += r.tok_turns                    || 0;
  }
  const wrap = el("div", { class: "metrics-bar" });
  let total_s = 0, total_in = 0, total_out = 0, total_cr = 0;
  for (const s of FSM_STATES) {
    const a = agg[s];
    const box = el("div", { class: "metric-box state-" + s + (a ? "" : " empty") });
    box.appendChild(el("div", { class: "metric-state" }, s));
    if (a) {
      box.appendChild(el("div", { class: "metric-time" }, fmtDuration(a.seconds)));
      const tokRow = el("div", { class: "metric-tokens" });
      tokRow.appendChild(el("span", { class: "tok-in",  title: "input tokens" },  "↓" + fmtTokens(a.in)));
      tokRow.appendChild(el("span", { class: "tok-out", title: "output tokens" }, "↑" + fmtTokens(a.out)));
      if (a.cache_r) tokRow.appendChild(el("span", { class: "tok-cache", title: "cache read" }, "⟳" + fmtTokens(a.cache_r)));
      box.appendChild(tokRow);
      box.appendChild(el("div", { class: "metric-turns" }, `${a.turns} turn${a.turns !== 1 ? "s" : ""}`));
      total_s += a.seconds; total_in += a.in; total_out += a.out; total_cr += a.cache_r;
    } else {
      box.appendChild(el("div", { class: "metric-time empty" }, "—"));
    }
    wrap.appendChild(box);
  }
  // Total summary box
  const tot = el("div", { class: "metric-box metric-total" });
  tot.appendChild(el("div", { class: "metric-state" }, "TOTAL"));
  tot.appendChild(el("div", { class: "metric-time" }, fmtDuration(total_s)));
  const trow = el("div", { class: "metric-tokens" });
  trow.appendChild(el("span", { class: "tok-in" },  "↓" + fmtTokens(total_in)));
  trow.appendChild(el("span", { class: "tok-out" }, "↑" + fmtTokens(total_out)));
  if (total_cr) trow.appendChild(el("span", { class: "tok-cache" }, "⟳" + fmtTokens(total_cr)));
  tot.appendChild(trow);
  wrap.appendChild(tot);
  return wrap;
}

function buildTimeline(current, history) {
  const wrap = el("div", { class: "timeline" });
  for (let i = 0; i < FSM_STATES.length; i++) {
    const s = FSM_STATES[i];
    const cls = "step" + (s === current ? " current" : "");
    wrap.appendChild(el("span", { class: cls }, s));
    if (i < FSM_STATES.length - 1) wrap.appendChild(el("span", { class: "arrow" }, "→"));
  }
  return wrap;
}

// ---------- Transcript pane ----------
async function renderTranscriptPane() {
  const body = $("transcript-body");
  // Pick transcript path based on selected agent.
  let path = null;
  if (state.selectedAgent === "main") {
    path = state.manifest?.main?.transcript_path;
  } else {
    const sa = state.manifest?.subagents?.find(s => s.aid === state.selectedAgent);
    path = sa?.transcript_path || null;
  }
  if (!path) {
    body.innerHTML = '<div class="placeholder">No transcript file for this agent. (For ledger-only subagents, switch to action tab.)</div>';
    return;
  }
  body.innerHTML = '<div class="placeholder">Loading…</div>';
  try {
    const text = await fetchText(`data/${state.sid}/${path}`);
    const blocks = parseTranscript(text);
    body.innerHTML = "";
    const header = el("div", { class: "transcript-header" },
      `Showing ${state.selectedAgent === "main" ? "main session" : "subagent " + state.selectedAgent.slice(0, 8)} — ${blocks.length} blocks · ${path}`
    );
    body.appendChild(header);
    for (const b of blocks) body.appendChild(renderBlock(b));
    bindTranscriptFilters();
    applyTranscriptFilters();
  } catch (e) {
    body.innerHTML = `<div class="placeholder">Error: ${e.message}</div>`;
  }
}

function parseTranscript(text) {
  // Blocks delimited by lines starting with "── ROLE …" produced by extract_transcript.py
  const blocks = [];
  const lines = text.split(/\r?\n/);
  let cur = null;
  const headRe = /^──\s+([A-Z_]+)\s+(?:\[(.+?)\]\s+)?(?:───\s*(.*?)\s*)?───\s*$/;
  for (const ln of lines) {
    const m = ln.match(headRe);
    if (m) {
      if (cur) blocks.push(cur);
      cur = { role: m[1].toLowerCase(), meta: (m[2] || "") + (m[3] ? " " + m[3] : ""), text: "" };
    } else if (cur) {
      cur.text += ln + "\n";
    }
  }
  if (cur) blocks.push(cur);
  return blocks;
}

function renderBlock(b) {
  const div = el("div", { class: `tr-block role-${b.role}` });
  div.dataset.role = b.role;
  div.dataset.text = b.text.toLowerCase();
  const head = el("div", { class: "tr-head" }, `${b.role}${b.meta ? "  ·  " + b.meta : ""}`);
  div.appendChild(head);
  const pre = el("pre");
  pre.textContent = b.text.trimEnd();
  div.appendChild(pre);
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

function esc(s) { return String(s).replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[c])); }

loadSessionIndex();

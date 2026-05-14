# v3 Plan — 重构 Workflow,把"自检"换成"外检 + 中段拦截 + 按需加载"

> 起草: 2026-05-13
> 上下文: 指挥官指出 4 个根本性问题。本 plan 给出统一架构 + 逐项落地。
> 状态: 草案,等指挥官 review 后开工。

---

## 0. 设计总纲

**核心转变**(三句话):

1. **规则源不再常驻 context** — `CLAUDE.md` 删,改成"注入文字 = router 指针 + AI 按需 Read 小文件"。
2. **审查不再靠 AI 自评** — Haiku **tool-calling** subagent 跑结构化合规检查;反思也派出去做。
3. **中段拦截不再缺位** — `PreToolUse` 在 Bash/Edit/Write/Agent 前**强制重问一次**(派兵守则 / observables 守则 / record-before-op 守则)。

---

## 1. 指挥官提的 4 个点 — 逐条对应方案

### 1.1 Haiku JSON 输出 → 用 tool-calling,不靠文本

**问题**: 之前给的方案是 `claude -p` 文本输入 + 输出 `<output>JSON</output>` + 文本 parse + 重试 — 不稳定。

**正解**: 用 **Anthropic SDK tool-calling**(或 Claude Code Agent tool 的等价机制)

#### 方案 A: 外部 Python wrapper(推荐)

```python
# scripts/jw_haiku_check.py
import anthropic, json, sys
client = anthropic.Anthropic()
res = client.messages.create(
    model="claude-haiku-4-5-20251001",
    max_tokens=2000,
    tools=[{
        "name": "compliance_verdict",
        "description": "Issue compliance verdict for this turn",
        "input_schema": {
            "type": "object",
            "properties": {
                "turn_id": {"type": "string"},
                "violations": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "rule": {"type": "string", "enum": ["D1","D2","D3","D4","D5","D6"]},
                            "evidence": {"type": "string"},
                            "severity": {"type": "string", "enum": ["high","medium","low"]}
                        },
                        "required": ["rule","evidence","severity"]
                    }
                },
                "recorded": {"type":"array", "items":{"type":"object"}},
                "missing_records": {"type":"array", "items":{"type":"object"}},
                "verdict": {"type":"string","enum":["PASS","FAIL","NEEDS_REMEDIATION"]},
                "remediation_actions": {"type":"array","items":{"type":"string"}}
            },
            "required": ["turn_id","verdict","violations","recorded","missing_records"]
        }
    }],
    tool_choice={"type":"tool","name":"compliance_verdict"},  # 强制走这个 tool
    messages=[{"role":"user","content": sys.stdin.read()}]
)
# tool_use block 的 .input 字段就是 schema 保证的 JSON
for block in res.content:
    if block.type == "tool_use" and block.name == "compliance_verdict":
        print(json.dumps(block.input))
        sys.exit(0)
sys.exit(1)  # 没走 tool
```

**优点**:
- API 层强制 schema → 模型只能通过 tool_call 返回,无法输出散文
- 不需要文本 parse + 重试
- 失败原因清晰(API error / tool_use missing / schema validation)

**重试 + fallback 包装**(bash):
```bash
for i in 1 2 3 4 5; do
  out=$(echo "$INPUT" | python3 scripts/jw_haiku_check.py 2>&1) && break
  echo "[retry $i] $out" >&2
done
if [ -z "$out" ]; then
  echo '{"verdict":"FALLBACK","reason":"haiku unreachable after 5 retries"}' > .claude_status/compliance_fallback.flag
  # 主线程读 fallback flag → 拒 stop + 要求 Commander 手动 review
fi
```

#### 方案 B: Claude Code 内置 Agent tool

派 subagent 时 Claude Code 已经支持 tool-calling(`Agent` 工具有自己的 tool 列表)。可以定义一个 sub-skill 叫 `compliance-check`,subagent 只允许调用 `compliance_verdict` 这一个工具,输入结构化 → 直接得 JSON。但目前 sub-skill 不支持外部强制 tool_choice,所以方案 A 更稳。

#### 推荐: 方案 A,放 `scripts/jw_haiku_check.py`,bash hook 调用 + 5 次重试 + fallback flag

---

### 1.2 反思 prompt 必须 follow 4 要素

**4 要素回顾**(来自 inject_decrees.sh 的 PROMPT REINFORCEMENT KIT):

| # | 要素 | 含义 |
|---|------|------|
| 1 | Observable vars | 每个变量含 `cmd (<1s) + expected + failure signal` |
| 2 | Monitoring cadence | 每 N min / retest each change / 3-fail then escalate |
| 3 | Reflection requirements | [REFLECT-A/B/C/D] 到 action log,4 module 必填 |
| 4 | Completion definition | 可机器验证,不是 "I think it's good" |

**之前的反思 prompt** 只命中 (3),缺 (1)(2)(4) → 反思出来的内容很空泛,没法 retest。

#### 修订版 ReflectAgent 任务 prompt 模板

```
你是反思代理。任务情境如下:

GOAL: <来自 goal.md>
HISTORY: <最近 N 个 turn 的 action.md 段落>
LATEST_OBSERVATIONS: <observations.log tail>

请按以下 4 要素结构输出 markdown(不要走过场,每项要可机器验证):

## (1) Observable variables(每条:name + cmd <1s + expected_range + fail_signal)
- 例: `gpu_util` / `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader` / `expected: >= 80%` / `fail_signal: < 30% sustained 5min`
- 必须列至少 5 个,涵盖 GPU/CPU/IO/queue/任务输出 五个维度

## (2) Monitoring cadence(每条 observable 都要):
- 频率: 每 N min 一次 / 每次改完 retest / 3 次失败上报
- 谁查: 主线程 / 外部 Haiku watcher / cron

## (3) Reflection (REFLECT-A/B/C/D — 这是 META,本字段说"下一次反思要看什么"):
- REFLECT-A: 守则自检要点(D1-D6 逐条)
- REFLECT-B: 哪些 observable 该有但没列?
- REFLECT-C: 哪些 observable 值偏离 expected?对应啥 bug 假设?
- REFLECT-D: 当前最大不确定性 + 下一步验证手段

## (4) Completion definition(任务何时算完):
- 必须 PASS 的 retest 命令清单(每条:cmd + expected exact output / threshold)
- 失败模式清单(哪些观察值出现就视为 "未完成需返工")

输出严格 markdown,每条带具体数字和命令,不准写 "TBD" / "未知" / "需要进一步研究"。
```

**这个 prompt 满足**:
- ✅ Observable vars(明确要求,且必须 5+)
- ✅ Monitoring cadence(每条要带频率)
- ✅ Reflection 4 模块要点
- ✅ Completion definition(机器可验)

---

### 1.3 PreToolUse 多派兵守则注入

**指挥官想法**: AI 想用 Bash/Edit/Write 前,先 inject "除了 X 情况必须派兵,现在是否符合 X?"让他多想一次。

**Claude Code PreToolUse 机制**:
- hook 接收 `{tool_name, tool_input, ...}` JSON
- hook 输出 `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"|"allow"|"deny","permissionDecisionReason":"..."}}` 或 `{"decision":"block","reason":"..."}`
- 如果 reason 非空,AI 会看到这段消息作为 system 指令,自然"多想一次"

#### 守则 inject 模板(per tool_name)

```bash
# hooks/pretooluse_dispatch_check.sh
input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name')
inp=$(echo "$input" | jq -r '.tool_input')

case "$tool" in
  Read|Grep|Glob)
    # 计数器:本 turn 已读几次?
    cnt=$(cat /tmp/jw_read_count_$session 2>/dev/null || echo 0)
    cnt=$((cnt + 1))
    echo $cnt > /tmp/jw_read_count_$session
    if [ "$cnt" -gt 1 ]; then
      jq -n --arg n "$cnt" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: "守则:除非「只读 1 个文件 且确认不需要后续操作」,否则必须派 Agent (run_in_background=true)。本 turn 你已读 \($n) 次。当前 Read 是否真符合「单文件 + 不连环」例外?如不符合,请改派 Agent。如符合,在 action.md 写 [SINGLE_READ_JUSTIFY] 一句话理由再继续。"
        }
      }'
    fi
    ;;
  Edit|Write)
    # 检查 action.md 本 turn 段落里有没有 [PLAN] 或 [RECORD-BEFORE-OP]
    action="$cwd/militar_camp/corporal_*/corporal_action.md"
    current_turn=$(awk '/^### TURN/{buf=""} {buf=buf"\n"$0} END{print buf}' $action 2>/dev/null)
    if ! echo "$current_turn" | grep -qE "\[PLAN\]|\[RECORD-BEFORE-OP\]"; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: "守则 D4: record-before-op。本 turn 的 action.md 还没看到 [PLAN] 或 [RECORD-BEFORE-OP] 标记。请先 Edit action.md 写一行 [PLAN] 说明这次 Edit/Write 要改啥、为啥、预期效果,再继续。"
        }
      }'
    fi
    ;;
  Bash)
    cmd=$(echo "$inp" | jq -r '.command // ""')
    bg=$(echo "$inp" | jq -r '.run_in_background // false')
    # 长任务但没 run_in_background → 拦
    if echo "$cmd" | grep -qE "sbatch|train.py|python.*train|torchrun|deepspeed"; then
      if [ "$bg" != "true" ]; then
        jq -n '{
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "守则 D3: 长任务必须 run_in_background=true + Monitor 工具周期查。当前命令看起来是训练/sbatch 但 bg=false。修正后重试。"
          }
        }'
      fi
    fi
    ;;
  Agent)
    # 派兵正常,放行,但提醒检查 Iron Rules
    exit 0
    ;;
esac
exit 0  # 默认 allow
```

**关键**: hook **不需要** AI 真的"思考一次" — hook 输出 reason 后 Claude Code 会**真的把 reason 当 system 消息塞回**,AI 必须先回应这条消息(或修改 tool input)才能继续。

#### 守则文件按需引用

每个 PreToolUse 分支的 reason 字符串本身就是"小守则"。如果需要详细规则,可以指向 `~/.claude/rules/dispatch.md` 等:
```
permissionDecisionReason: "守则:Read 派兵规则详见 ~/.claude/rules/dispatch.md。本 turn 你已 Read 3 次,请确认是否走例外。如确认,在 action.md 写 [SINGLE_READ_JUSTIFY] 理由后继续。"
```
AI 看到这段,如果不熟规则会自己 Read 那个文件 — **按需加载**。

---

### 1.4 CLAUDE.md + 注入文字 → router 化 + 拆分 rules

**问题**:
- `CLAUDE.md` 约 7KB,每次开 session **全文常驻 context**
- 注入文字(inject_decrees.sh)9KB,每个 UserPromptSubmit + 每个 PostToolUse:Agent 都注入,长 session 累积巨大
- 大部分内容 90% 时间用不上(比如"3 failures escalate"在正常 turn 完全不需要)

**新架构 — router + 按需加载**:

```
~/.claude/CLAUDE.md                         ← 删除(或保留极小的 "see router")
~/.claude/rules/router.md                   ← 主 router(< 1KB,所有 session 都会 auto-load)
~/.claude/rules/decrees/                    ← 拆成多个小文件,按 trigger 引用
  ├── d1_identity.md           (~300 字, AI 自报身份时 read)
  ├── d2_facts_first.md        (~500 字, 用 [INFERENCE] 时 read)
  ├── d3_dispatch.md           (~500 字, 派兵/长任务时 read)
  ├── d4_recording.md          (~500 字, 出违规自承时 read)
  ├── d5_reading.md            (~150 字, 始终用 Read tool)
  ├── d6_workflow.md           (~600 字, hands-on 任务时 read)
  └── m6_autonomous.md         (~300 字, 3 failures 时 read)
~/.claude/rules/iron_a_to_g.md              ← Private 专用 (subagent 才需要)
~/.claude/rules/destructive_checklist.md    ← 8 项危险操作清单
```

**router.md 内容**(约 800 字,常驻):
```
# Router — 按需加载守则

你是下士 Claude。称对方"指挥官",自称"下士"。详 → ~/.claude/rules/decrees/d1_identity.md

四个触发器 → 读对应规则:
1. 用 [INFERENCE]? → 必读 d2_facts_first.md
2. 派兵 / 跑长任务? → 必读 d3_dispatch.md
3. 出错自承 ("我违规了"/"forgot"/...) ? → 必读 d4_recording.md
4. 第 3 次连续失败? → 必读 m6_autonomous.md + 项目根 CLAUDE.md (AUTH 检测)

记账三件套:
- 本 turn 工作: $PWD/militar_camp/corporal_X/corporal_action.md (per-turn 原子流)
- 跨轮意图汇总: $PWD/militar_camp/attempts_ledger.md (ATT-N)
- 经验教训: $PWD/militar_camp/{bitter_lessons,successful_fixes}.md

合规检查由 Haiku 外审 (PreToolUse hook + Stop hook 调用),不再靠你自评。

如果不确定怎么做 → 读 ~/.claude/rules/index.md(完整规则索引)
```

**注入文字(inject_decrees.sh)收缩**:
- 删掉所有 Decree 全文
- 只保留**核心 trigger 速查表**(约 1.5 KB):"如果做 X → read rules/Y.md"
- 加一条:"PreToolUse hook 会守则你 — 不要把守则当口号 recite,该 read 就 read"

#### "能否主动 dismiss?"

**坏消息**: Claude Code 没有 "evict-from-context" API。一旦 Read 进 context,本 turn 内无法主动 dismiss。

**好消息**: 你不需要主动 dismiss,只需要:
1. **不 auto-load** — 改 router 模式后,80% 规则不会进 context
2. **跨 turn 自然 fade** — 长 session 里 Claude Code 内部有 sliding window;不再被引用的规则会被 compaction 推走
3. **`/clear` 或 `/compact`** — 指挥官手动触发,清空 context 重新开始
4. **rule 文件本身不长** — 即使 read 进来一个 d2_facts_first.md(500 字),也比常驻 7KB CLAUDE.md 便宜 14x

#### 迁移路径

| 步骤 | 操作 |
|------|------|
| ① | 把现 CLAUDE.md 按 D1-D6 拆成 7 个小 md → `content/templates/global_rules/decrees/*.md` |
| ② | 写 `router.md`(~800 字)放 `content/templates/global_rules/router.md` |
| ③ | 改 `set_claude.sh` 把这堆部署到 `~/.claude/rules/` |
| ④ | 改 `inject_decrees.sh` → 9KB → 1.5KB router 速查表 |
| ⑤ | 删 `~/.claude/CLAUDE.md`(留个 stub 指向 router) |
| ⑥ | 在 router 末尾加"读 ~/.claude/rules/index.md 看完整索引",index.md 列所有规则文件清单 |

---

## 2. 整体新架构(架构图)

```
┌─────────────────────────────────────────────────────────────┐
│                     CLAUDE CODE SESSION                      │
└───────┬─────────────────────────────────────────────────────┘
        │
        ├─[UserPromptSubmit hook]──► inject 1.5KB router
        │                            (替代 9KB Decrees 全文)
        │
        ├─[AI 主线工作]
        │   ├─用 [INFERENCE]→ Read d2_facts_first.md(按需)
        │   ├─派 Bash/Edit/Write/Agent
        │   │
        │   └─[PreToolUse hook]─► 调 守则 check (≤50ms)
        │                          ├─Read 多次 → ask "符合派兵例外?"
        │                          ├─Edit/Write → ask "[PLAN] 写了吗?"
        │                          ├─Bash 长任务 no-bg → deny
        │                          └─Agent → allow (注入 Iron Rules)
        │
        ├─[Stop hook]──► 调 Haiku tool-call 合规审查
        │                ├─输入: 本 turn 的 action.md 段 + transcript tail
        │                ├─输出: JSON {violations, recorded, verdict}
        │                ├─verdict=PASS → 允许 stop
        │                ├─verdict=NEEDS_REMEDIATION → block + 给 remediation_actions
        │                ├─verdict=FAIL → block + 要求写 W-XXX
        │                └─5 次重试 → fallback flag → Commander 介入
        │
        └─[PostToolUse:Agent hook]──► subagent 完成回主线 → 重新 inject router
```

---

## 3. 落地步骤(P1-P6,跟之前次序一致但加细)

| P | 工作 | 文件 | 工时 |
|---|------|------|------|
| **P1** | Haiku tool-call wrapper | `scripts/jw_haiku_check.py` + bash 包装 | 2-3h |
| **P2** | router.md + 拆 decrees → 7 个小 md | `content/templates/global_rules/router.md` + `decrees/*.md` | 1-2h |
| **P3** | 收缩 inject_decrees.sh(9KB→1.5KB) | `hooks/inject_decrees.sh` | 30min |
| **P4** | PreToolUse 守则 check hook | `hooks/pretooluse_dispatch_check.sh` + 注册 settings.json | 2-3h |
| **P5** | 改 stop_self_audit.sh:gate 检查换成 Haiku tool-call | `hooks/stop_self_audit.sh` | 2h |
| **P6** | ReflectAgent 修订 prompt(4 要素) | `content/templates/reflect_agent_prompt.md` | 1h |

**总计**: ~10 小时。一天工作量。

**最小可跑 demo**: P1 + P5(最小验证 — Haiku 接管 gate 审查)。其余迭代。

---

## 4. 抉择点 — 等指挥官拍板

| # | 决策 |
|---|------|
| 1 | Haiku tool-call wrapper 用 Anthropic Python SDK 还是 Claude Code 内置 Agent tool?**推荐 SDK**(更可控) |
| 2 | API key 怎么管?读 `~/.claude/config.json` 还是单独 `~/.claude/haiku_key`? |
| 3 | router.md 长度上限?**建议 1 KB** |
| 4 | PreToolUse 守则触发频率:每次 Read 都拦还是 N+1 才拦?**推荐 N=2**(第二次开始拦) |
| 5 | Stop hook Haiku 失败时 fallback:拦截要求 Commander 介入,还是放行 + 标 `fallback-no-audit`? |
| 6 | CLAUDE.md 是真删,还是保留一个 stub `# See ~/.claude/rules/router.md`? |
| 7 | rules/ 部署到 `~/.claude/rules/`(global)还是 `$PWD/.claude/rules/`(per-project)? |
| 8 | 现有 W-XXX / L-XXX 文件(`~/.claude/rules/violation.md` / `lessons.md`)怎么处理 — 跟新 decrees/ 并存还是合并 |

---

## 5. 风险

- **Haiku 限流 / 故障** → fallback flag → 增加 Commander 决策成本。需测试稳定性(可跑 100 次 turn 看失败率)
- **PreToolUse 误拦** → 影响速度。需要白名单(如 cwd 内单文件 Read 一次允许)
- **拆 rules 后 AI 不 read** → 守则失效。对策:router 里写"违反 = 立刻 W-XXX",PreToolUse hook 检测到典型违规(>1 Read 无理由 / Edit 无 [PLAN])自动 inject 守则 read 提示
- **指挥官失去 CLAUDE.md 一站式 review** → 在 git repo 里保留一个 `content/CLAUDE.md` 作"合订本",`set_claude.sh` 部署时不再 cp 到 `~/.claude/`,但留作文档

---

## 6. 不在本 plan 范围

- ReflectAgent 自动派(§10 提的)— 是另一个 layer,需要 P1-P6 跑顺再叠
- bug-fix 流程 multi-reflection 接入(§10 提的)— 同上
- v4 visualization 同步更新 — 等架构稳定再改

---

**作者**: 下士(草案);**等审**: 指挥官 review + 抉择 8 个决策点 → 开工。

---

## 7. 工作流即状态机(Workflow-as-FSM)— v3 的核心 idea

### 7.1 想法

指挥官提议: 把整个 workflow 建成显式状态机,而不是靠一团松散的守则 + 反思:

- **state.json** 维护"当前 stage + 已完成 stage + fork 历史"
- **每个 stage 有完成脚本** `stage<N>_complete.sh` — AI 主动调用 → 脚本改 state.json → hook 监听到状态变化 → 注入下一段 prompt 给 AI
- **AI 只能看见当前 stage 允许的指令**(下一段 prompt 直到上一段完成才暴露)
- **跨工具兼容**: state.json + completion 脚本是工具无关的;只有"注入"层各家不同

这是 **轻量级外部 orchestrator** — 不需要 Python driver、不需要 `claude -p --resume` 复杂调度,所有逻辑都在 hook + 脚本里。

### 7.2 三件套设计

#### (a) 状态文件 `$PWD/.claude_status/workflow_state.json`

```json
{
  "task_id": "train-llm-gsm8k-2026-05-13",
  "current_stage": "stage2_dispatch",
  "stage_history": [
    {"name": "stage1_read_boards", "completed_at": "2026-05-13T05:01Z", "completion_evidence": "stage1_complete.sh exit=0, board_files_md5=..."},
    {"name": "stage2_dispatch", "started_at": "2026-05-13T05:05Z"}
  ],
  "fork_decisions": [
    {"at_stage": "stage4_bug_observed", "choices": ["repro_script", "full_rerun"], "chose": "repro_script", "reason": "前置可隔离"}
  ],
  "next_allowed_stages": ["stage3_monitor"],
  "blocked_until": null
}
```

#### (b) 完成脚本 `~/.claude_status/stages/stage<N>_complete.sh`

```bash
#!/bin/bash
# stage1_complete.sh — 报告 stage1 已完成,要求列出证据
set -e
STATE_FILE="$PWD/.claude_status/workflow_state.json"

# 1. 收集本 stage 完成证据(由 AI 提前 export 环境变量或 stdin)
EVIDENCE=$(cat <<EOF
files_read: $(jq -r '.boards_read | length' $PWD/.claude_status/board_progress.json)
turn_marker: $(awk '/^### TURN/' $PWD/militar_camp/corporal_*/corporal_action.md | tail -1)
goal_md_read: $(test -f /tmp/jw_goal_read_flag && echo yes || echo no)
EOF
)

# 2. 校验本 stage 必要 deliverable
if [ "$(echo "$EVIDENCE" | grep -c yes)" -lt 1 ]; then
  echo "REJECTED: stage1 deliverable 不齐(需读 boards + goal.md + 写 TURN marker)" >&2
  exit 1
fi

# 3. 更新 state.json
python3 -c "
import json, sys
from datetime import datetime
s = json.load(open('$STATE_FILE'))
ts = datetime.utcnow().strftime('%Y-%m-%dT%H:%MZ')
s['stage_history'].append({'name':'stage1_read_boards','completed_at':ts,'completion_evidence':'$EVIDENCE'})
s['current_stage'] = 'stage2_dispatch'
s['next_allowed_stages'] = ['stage2_dispatch']
json.dump(s, open('$STATE_FILE','w'), indent=2)
"
echo "OK: stage1 done, transitioned to stage2_dispatch"
```

#### (c) 注入 hook — PostToolUse:Bash 监听完成脚本

```bash
# hooks/posttooluse_stage_dispatch.sh
input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name')
[ "$tool" != "Bash" ] && exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
# 匹配 stage<N>_complete.sh
if echo "$cmd" | grep -qE 'stage[0-9]+_complete\.sh'; then
  exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // 1')
  if [ "$exit_code" = "0" ]; then
    # 完成成功 → 读 state.json → 注入下一段 prompt
    next_stage=$(jq -r '.current_stage' .claude_status/workflow_state.json)
    next_prompt=$(cat ~/.claude/workflows/stages/${next_stage}_prompt.md)
    jq -n --arg p "$next_prompt" --arg s "$next_stage" '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("✅ Stage 完成。下一阶段 = " + $s + "\n\n" + $p)
      }
    }'
  else
    # 完成失败 → 注入"你的 deliverable 不齐"
    err=$(echo "$input" | jq -r '.tool_response.stderr // ""')
    jq -n --arg e "$err" '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("❌ Stage 完成脚本拒收: " + $e + "\n请补齐 deliverable 再调用一次,不要进下一 stage。")
      }
    }'
  fi
fi
exit 0
```

**关键**: 注入路径 = PostToolUse hook output 的 `additionalContext`(Claude Code 原生),会被作为下一步 system 消息塞回 AI。

### 7.3 硬编码路径 vs 决策路径 — 分类讨论

| 路径类型 | 例子 | 怎么编码 | AI 自由度 |
|---------|------|---------|----------|
| **硬编码线性** | stage1 read boards → stage2 dispatch → stage3 monitor → stage4 reflect | state.next_allowed_stages 始终 1 项,AI 没得选 | 0 (机械执行) |
| **硬编码并行** | stage3a observe_gpu + stage3b observe_loss(同时进行)→ stage4 merge | next_allowed_stages 含多项,但全部必做才能进 stage4 | 顺序自由,内容必做 |
| **决策 fork** | stage4_bug_observed → 选 (a) 复现脚本 / (b) full rerun / (c) 改 hypothesis 重试 | next_allowed_stages 列所有选项,AI 选一个并把 `chose` + `reason` 写 state.fork_decisions | 必须给 reason |
| **回退 loop** | stage5_retest 失败 → 回 stage4 | state.history 显示已尝试,回去时携带"上次失败 evidence" | 必须基于新 evidence |
| **跳过条件** | Q&A turn 不需要 stage2-5 | state.task_type=q-and-a → 直接 stage_final | 任务类型决定 |

### 7.4 哪些必须硬编码,哪些必须决策

**硬编码强制**(防 AI 跳步,无 fork):
- ✅ stage1 必须读 boards + goal.md(不能直接动手)
- ✅ Bash 长任务 launch 后 ≤1min 必须 Monitor 验证 running(D3)
- ✅ 出 bug → 必须先 dispatch ReflectAgent brainstorm 假设(不能直接 patch)
- ✅ ReflectAgent 返回 → 必须排除阶段(再次 dispatch)
- ✅ retest 3-Q 必须全 YES 才能进 stage_final

**决策 fork**(给 AI 选,但必须写 reason):
- 🔀 bug 假设排除后 → 选 "写复现脚本" vs "改 1 个参数试 full rerun" vs "查更多代码"
- 🔀 3 次失败后 → 检查 AUTH override → 选"继续尝试 vs 上报指挥官"
- 🔀 复现脚本写完 → 选"先跑复现确认 bug vs 直接基于复现 patch"
- 🔀 修完 → 选"只跑复现验证 vs 同时跑 full 验证"

**禁止 fork**(必须按死法走,无选项):
- ❌ "我自己反思 vs 派 ReflectAgent" — 永远是后者
- ❌ "记 W-XXX vs 不记" — 必须记
- ❌ "更新 action.md vs 跳过" — 必须更新

### 7.5 跨工具兼容(Claude / Codex)

| 层 | Claude Code | Codex CLI | 共享? |
|----|-------------|-----------|------|
| **state.json** | 文件 | 文件 | ✅ 同一文件 |
| **stage<N>_complete.sh** | bash | bash | ✅ 同一脚本 |
| **完成检测 → 注入** | PostToolUse hook | Codex 也有 hooks(参见 `set_codex.sh` 部署的 hooks/) | ⚠️ 各家配置不同,内容相同 |
| **stage prompt 模板** | markdown | markdown | ✅ 同一文件 `~/.claude/workflows/stages/*.md` |
| **审查 (Haiku tool-call)** | 调 Anthropic SDK | 调 Anthropic SDK 或 Codex 内部 | ✅ Python 脚本相同 |
| **守则文件 `rules/*.md`** | `~/.claude/rules/` | `~/.codex/rules/`(set_codex.sh 已有处理) | ✅ 内容同步,部署不同 |

**跨工具部署**: `set_claude.sh` 和 `set_codex.sh` 各自把 hooks 注册到 `~/.claude/settings.json` / `~/.codex/config.toml`,但**指向同一套** state.json / 完成脚本 / stage prompts。AI 不知道自己跑在哪个工具上,完全无感。

### 7.6 stage prompt 模板示例(stage2_dispatch_prompt.md)

```markdown
# Stage 2 — Dispatch

## 4 要素

(1) Observable variables
   - dispatch_status: `cat $PWD/.claude_status/dispatch.log | tail -1` / expected: "agent_id=..." / fail: "ERROR"
   - subagent_progress: `ls -la $PWD/militar_camp/corporal_*/number*/soldier_action.md` / expected: mtime < 60s old / fail: file missing or stale

(2) Monitoring cadence
   - 派出后 ≤60s 必须读 soldier_action.md
   - 每 5min 检查 subagent 是否还活着

(3) Reflection requirements
   - 派出前调用 ReflectAgent(stage1 输出 + 任务)→ brainstorm "派几个、每个负责什么、有哪些 failure modes"
   - 派出后调用 ReflectAgent → "subagent prompt 是否含 4 要素 kit"

(4) Completion criterion
   - 至少 1 个 subagent 被派出,run_in_background=true
   - subagent 的 soldier_action.md 在 60s 内可见
   - 主线程在 corporal_action.md 写 [DISPATCH] 段记录每个 subagent 的 agent_id

## 进入下一阶段

完成所有 (4) → 调用 `bash ~/.claude_status/stages/stage2_complete.sh`
- 脚本会校验你的 deliverable 是否齐
- 如果齐 → state 切到 stage3,你会收到下一段 prompt
- 如果不齐 → 你会被退回继续补
```

### 7.7 优势 — 为什么这个 idea 好

| 旧设计(纯守则 + 自反思) | 新设计(FSM + 完成脚本) |
|------------------------|------------------------|
| AI 看到全部规则,信息过载 | 只看到当前 stage 的指令,焦点单一 |
| 跳步靠 AI 自觉 | 跳步靠脚本拒收 |
| 完成与否靠 AI 自评 | 完成与否靠脚本校验 deliverable |
| 反思敷衍说"OK" 即可 | reflection 是 stage 完成 deliverable 之一,缺了脚本 reject |
| 路径靠 prompt 描述 | 路径是 state.json 显式声明 |
| 跨工具难复用 | state.json + .sh 工具无关 |
| 审计难(检查 markdown) | 审计 = `jq` 检查 state.json + completion log |

### 7.8 风险 / 注意

- **AI 不调 stage_complete.sh 怎么办** → PreToolUse 守则:发现 AI 试图做"下一 stage 的动作"(如还没 stage1_complete 就想 Bash 训练)→ deny + 提醒"先调 stage1_complete.sh"
- **stage 太多 prompt 会成迷宫** → 限制深度 ≤ 7 stages,fork 深度 ≤ 2
- **stage_complete.sh 自己也可能被 AI 糊弄**(他改 state 跳进度) → 完成脚本必须查"客观证据"(文件 mtime / md5 / 命令实际跑过),不接受 AI 自报
- **重启 / 中断恢复** → state.json 持久化,重启直接读最后状态,继续

### 7.9 落地步骤(在 P1-P6 之外,作为 P7-P10)

| P | 工作 |
|---|------|
| **P7** | 设计 stage 集合 + state.json schema(写 `content/workflows/state_schema.json`)|
| **P8** | 写 stage_complete.sh 模板 + 5-6 个具体 stage 脚本 |
| **P9** | 写 PostToolUse hook 接管完成检测 + 注入下一段 |
| **P10** | 写 stage prompt 模板(6 个 md)|

**最小 demo**: 一个 task "用 grep 在 repo 找一个文件" 的 3-stage FSM
- stage1 = read README → stage1_complete 验证 README 真读了(mtime 检测) 
- stage2 = grep + 找到 → stage2_complete 验证 grep 输出非空
- stage3 = 报告 → final
跑通后再加复杂的(派兵 / 反思 / debug fork)。

### 7.10 跟之前 P1-P6 的关系

P1-P6 修的是 **现有架构的洞**(Haiku 审查 / PreToolUse / router / rules 拆分)
P7-P10 是 **架构的换血** — 把全部规则系统重组成 FSM

可以**并行做**,但建议:
- 先 P1+P2+P3(Haiku tool-call + router + 收缩注入) — 让现有架构没那么烂
- 再 P7 起步 — 改成 FSM,旧守则系统自然消化进 stage prompt

---

## 8. 总结 — v3 的完整愿景

```
┌─────────────────────────────────────────────────────────┐
│ v3: FSM-driven Workflow + 按需加载 Rules + 外审合规       │
├─────────────────────────────────────────────────────────┤
│ • 注入: 1.5KB router 指针,不再 dump 9KB Decrees          │
│ • 规则: ~/.claude/rules/decrees/*.md 按需 Read           │
│ • 路径: state.json 显式 FSM,stage_complete.sh 守门       │
│ • 守门: PreToolUse 中段拦截 + PostToolUse 注入下一段     │
│ • 审查: Haiku tool-call 强制 JSON schema,主线程不自评    │
│ • 反思: dedicated ReflectAgent 派出,主线程读+签字        │
│ • 跨工具: state + .sh + rules 文件全部工具无关           │
└─────────────────────────────────────────────────────────┘
```



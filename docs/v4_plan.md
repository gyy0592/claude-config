# v4_plan.md — Barry's Workflow v2 的实施计划

> 名字小坑：文件名 `v4_plan` 是因为这是第 4 次写计划草稿（v2 / v3 / v4 三次迭代），实际产出的项目叫 **Barry's Workflow v2**（v1 是早期军事 cosplay 规则）。

# v2 Plan — 状态机 + Rebuttal 反思 + KV cache + 去 cosplay

> 修订 2 (2026-05-13):基于 v4 原稿 inline comments + 新指令"去暴力化 / 去 cosplay"。
> 包含: 项目改名 + 术语去军事化 + Rebuttal 方向修正(主线程用 SendMessage 主导)+ KV cache 信 AI + Q1-Q8 答案落实 + Codex 兼容分析 + 现有 hook 迁移 + demo 任务定义。

---

## 0. 改名 + 去 cosplay(新指令)

### 0.1 项目名
原 `claude-config` / "militar_camp" / "下士/指挥官" → 改为中性。Commander 提到 "Barry's workflow"。建议项目根名:

| 候选 | 优劣 |
|------|------|
| `barry-workflow`(推荐)| 个人化、好记、跟现状最接近 |
| `barrys-workflow` | 同义,带所有格 |
| `flowstate` | 中性、抽象、跟"状态机"概念契合 |
| `taskflow` | 强调任务流 |
| `agent-pipeline` | 直白技术性 |

**默认采用 `barry-workflow`**(可改)。

### 0.2 术语映射(全面去军事 cosplay)

| 旧(cosplay)| 新(中性技术)|
|------------|--------------|
| 下士 / Corporal / 我 | AI / 主线程 / `main` |
| 指挥官 / Commander / 你 | user / 用户 / operator |
| 军营 / militar_camp/ | `workspace/` 或 `flow_state/` |
| 派兵 / dispatch private | dispatch subagent / spawn |
| Iron Rules A-G | subagent_rules.md |
| 六令书 / Six Decrees / 守则 | rules / policies |
| TREASON / 重罪 | policy_breach |
| violation.md | `rule_violations.md`(同语义)|
| bitter_lessons.md | 保留同名(技术语,中性)|
| corporal_X / soldier_X | `main_<sid>/` / `agent_<sid>/` |
| corporal_action.md | `action.md`(per state-machine instance)|
| soldier_action.md | `action.md`(in agent's dir)|

### 0.3 这一节先单独 commit,后续都用新术语写
计划文件、HTML、hook 注入文本一并改。set_claude.sh 重命名也是一次大改 — 但**不在本 plan 第一波**,先把语义内核改完再扫尾。

---

## 1. v3 vs v4 关键 delta(更新版)

| 主题 | v3 | v4 修订 2 | 决定来源 |
|------|----|---------|----------|
| 拆 CLAUDE.md + rules router | 有(§1.4)| **必做 #1** 继承 | — |
| 状态机 FSM | 有(§7)| **必做 #2** 细化到 4 status | — |
| 反思机制 | ReflectAgent 单向 ask-claude | **必做 #3** 改 rebuttal:**主线程 SendMessage 主导,subagent 写 markdown** | Q4 + line 148 comment |
| Haiku tool-call 合规审查 | 有 | **砍**(状态机解决就不需要)| Q8 comment |
| PreToolUse 中段拦截 | 有 详细 | **必做 #5** 但**简化** — 只发短提醒,不污染 context | Q8 comment |
| init_corporal.sh | 保留 | **删** 改 hook 在 BOOT 时自建 | 同 v4 原 |
| 多入口 REFLECT 复用 | 隐含 | **通用 1 个**(失败再讨论独立)| Q4 comment |
| EXECUTE 内循环 | 笼统 | 显式约束 + **AI 自判退出**(bug / 跑完)| Q6 comment |
| KV cache 命中 | 无 | **信 AI 自报** + 失败入 violation.md(不是 bitter) | Q2 + line 113/293 comment |
| subagent 编号 + state | 没说 | subagent 用自己的 session_id 派生 `agent_<sid>/`,**有独立 state.md** | Q1 + Q7 comment |
| state 文件格式 | 讨论 | **hybrid markdown + 内嵌 YAML 区块** | Q3 comment |
| rebuttal 上限 | N=5 拍 | N=5 实测,失败 fallback N=10 | Q5 comment |
| 项目改名 + 去 cosplay | 无 | **新增**(全面术语替换)| 本轮新指令 |
| 现有 hook 迁移 | 没说 | 详 § 6(reset 复用、stop 可弃) | line 402/406 comment |
| Codex 兼容工具对照 | 模糊 | 详 § 5 | line 400 comment |
| Demo 任务 | 没定 | HF 模型 + 100 题 GSM8K + activation hook + GPU/CPU 利用率约束 | line 404 comment |

---

## 2. 五项必做

### 必做 #1 — 拆 CLAUDE.md → `~/.claude/rules/*.md` + router 注入

继承原 v4 写法,微调:

```
~/.claude/CLAUDE.md                  ← 删(或 stub "see router")
~/.claude/rules/router.md            ← 800 字常驻,所有 session auto-load
~/.claude/rules/policies/d1..d6.md   ← 拆分(原 Decrees),按需 Read
~/.claude/rules/subagent_rules.md    ← subagent 专用规则(原 Iron Rules A-G)
~/.claude/rules/index.md             ← 文件索引

hooks/inject_router.sh:
  原 ~9KB 注入 → 新 ~1.5KB router 速查表
```

**router 速查表内容**(去 cosplay,纯触发器映射):
```
身份 / 自称 → policies/d1_identity.md
[INFERENCE] 用到 → policies/d2_facts_first.md
派 subagent / 长任务 → policies/d3_dispatch.md
出错记录 → policies/d4_recording.md
3 次失败上报 → policies/m6_autonomous.md + $PWD/CLAUDE.md (AUTH override)
派 subagent 时 → subagent_rules.md
危险操作 8 项 → destructive_checklist.md

不确定 → index.md(完整索引)
```

---

### 必做 #2 — 状态机 + 4 个 status

总体框架同 v4 原:

```
[BOOT] → [PREPARE] → [REFLECT] → [EXECUTE_LOOP]
                       ↑              ↓ (异常 / 完成)
                       └──────────────┘
[END]
```

每个 status 详细:

#### Status 1 — BOOT
- **hook 自建**: UserPromptSubmit hook 检测 `$PWD/<state_dir>/state_<sid>.md` 不存在 → 用模板建,`current_status=BOOT`
- **state_dir 命名**: `.barry_workflow/`(去 .claude_status,跟新项目名对齐)
- **公共工件**(`workspace/<task>/`)由 `set_claude.sh` 一次部署(bitter_lessons.md / attempts_ledger.md / successful_fixes.md / rule_violations.md / goal.md),所有 session 共用
- **AI 必须做**: Read `~/.claude/rules/router.md` 已注入,写 `[BOOT_DONE @ ts]` 到 `action_<sid>.md`,调 `transition.sh BOOT_DONE`

#### Status 2 — PREPARE
- **prompt 增强(M5)**: 检查用户指令 4 要素(observable / cadence / reflection / completion),缺写 `[PROMPT_REINFORCED]`
- **KV cache 命中检测**(信 AI 自报,Q2 答案):
  ```yaml
  cache_hit_map:
    goal.md:           { hit: YES, last_read_turn: 42, sig: md5_xxx }
    attempts_ledger:   { hit: NO,  must_read: true }
    bitter_lessons:    { hit: YES, last_read_turn: 40 }
  ```
  YES 项不重读,NO 项 Read
- **反作弊**(line 113/293 修正): 误判 cache → AI 行为错误 → 写 `rule_violations.md`(不是 bitter_lessons!)
- 调 `transition.sh PREPARE_DONE`

#### Status 3 — REFLECT(rebuttal,见必做 #3 详)

#### Status 4 — EXECUTE_LOOP
- 内循环: `[PLAN]` → `Bash/Edit/Agent` → 监控 `[OBSERVE]` → 判断
- **退出条件由 AI 自判**(Q6 答案):
  - AI 认为"任务完成 deliverable 齐" → 进 REFLECT (post-task 验证)
  - AI 认为"出 bug 了" → 进 REFLECT (on-anomaly 找根因)
  - 自判触发 `transition.sh EXECUTE_EXIT --reason=<...>`
- 强制约束: 每次循环必有 `[PLAN]` + `[OBSERVE]`;bg 任务 ≥X 分钟必 Monitor

---

### 必做 #3 — Rebuttal 反思(修正方向)

**v4 原稿写错了方向**(line 148 comment 指出)。**正确方向**:

```
主线程(SendMessage 主导发问)            Subagent(被动响应 + 写 markdown)
──────────────────────────              ───────────────────────────────
1. dispatch subagent (run_in_background=true)
   prompt: "你写 reflection_<sid>.md,
            然后 sleep 等我用 SendMessage 问你。"
                ↓
2. SendMessage(agent_id, "初始反思:
                  pre-task / on-anomaly / post-task,
                  请写 markdown 给我看")
                                          ↓
                                3. agent 写 markdown
                                          ↓ sleep + 等 SendMessage
                                          
4. 主线程 Monitor reflection_<sid>.md
   或 Read 直到看到新内容
                ↓
5. 主线程 SendMessage(agent_id, "我同意 X,
                       但 Y 我有疑问 ...
                       Z 是否可以排除 because ...")
                                          ↓
                                6. agent 接 SendMessage,
                                   更新 markdown 回应
                                          ↓ sleep 等下次
                                          
7. 主线程 Read 又看到更新
                ↓
8. ... 来回 N 轮(默认 5,失败 fallback 10) ...

最终: 任一方写 [CONSENSUS_REACHED] 或 N 轮上限 → 主线程 KillBash/TaskStop 终止 agent
```

**关键修正**:
- 主线程**主动用 SendMessage** — 是问询发起方
- subagent **被动等 SendMessage** — 写完 markdown 就 sleep 循环等
- markdown 是**共享视图**(双方都能 read),用于双方对照
- 不是双方都"主动写" — 主线程通过 SendMessage,agent 通过 markdown

**优势**:
- SendMessage 是 Claude Code 原生异步消息工具,不需要 hack 文件通信
- markdown 是审计载体,任何时候 Commander 都能看双方说了啥
- agent 不需要轮询主线程信号 — 等 SendMessage 自然 wake

**rebuttal max=5 试 → 不行 fallback 10**(Q5 答案):demo 先 N=5 跑,看 case 收敛率,不行调 10。需要实测。

**REFLECT 用通用 1 个**(Q4 答案):同一个 reflection agent prompt + 入参 `reason=pre-task|on-anomaly|post-task`。失败 → 调试 prompt。实在不行 → 请示 Commander 才考虑独立 3 个。

---

### 必做 #4 — KV cache 命中检测

详见 § 2 Status 2 PREPARE。**信 AI**(Q2 答案)+ 失败入 **rule_violations.md**(不是 bitter_lessons!line 113/293 修正)。

边界澄清(line 113 comment):

| 文件 | 内容 | 例 |
|------|------|---|
| `rule_violations.md` | **AI 自己**行为错误 | "AI 误判 cache 命中"、"AI 没派 subagent 就直接 read 5 文件"、"AI 没写 record-before-op" |
| `bitter_lessons.md` | **项目技术**踩坑 | "bs=32 在这卡上必崩"、"torch compile 跟 flame 不兼容"、"NCCL backend p2p_disable 在跨机失败" |
| `attempts_ledger.md` | 跨轮意图汇总(ATT-N) | "ATT-3: 试 bs=16 修 OOM, verdict: 还崩" |
| `successful_fixes.md` | 最终成功的修复(FIX-N) | "FIX-1: bs=8 + grad_ckpt 解 OOM, validated" |

---

### 必做 #5 — PreToolUse 短提醒(从 v3 砍后简化加回)

**Q8 comment**: "PreToolUse 优先级高一点,反正就是一两句话提醒他:'你用 subagent 了吗?''你需要做记录吗?' 这种,合规性检验,**要短简单不要污染 context**。"

设计:`hooks/pretooluse_short_nudge.sh`(每条 reason ≤ 100 字)

```bash
case "$tool_name" in
  Read|Grep|Glob)
    # 第 2 次起提醒派 subagent
    cnt=$(读计数器)
    [ "$cnt" -ge 2 ] && echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"已 read '$cnt' 次。多文件 / 大量内容 → 派 subagent?"}}'
    ;;
  Edit|Write)
    # 提醒 record-before-op
    last_action_mtime=$(stat action.md)
    [ ... 上一行不是 [PLAN] ... ] && echo '{"...","permissionDecisionReason":"D4: 改文件前先在 action.md 写 [PLAN]?"}'
    ;;
  Bash)
    cmd=$(echo "$inp" | jq -r '.tool_input.command')
    bg=$(echo "$inp" | jq -r '.tool_input.run_in_background')
    if echo "$cmd" | grep -qE "sbatch|train|deepspeed"; then
      [ "$bg" != "true" ] && echo '{"...","permissionDecisionReason":"长任务 run_in_background=true + Monitor 验证?"}'
    fi
    ;;
esac
```

**对比 v3 详细版**:
- v3 让 hook 弹大段守则,污染 context
- v4 只一句话,**指针 + 反问** — AI 看到这一句要么改正要么 read 详细规则(rules/d3_dispatch.md)

---

## 3. 文件分层 + 边界(澄清)

```
项目根($PWD):
├── workspace/<task>/                 ← 公共工件,所有 session 共用(set_claude.sh 部署)
│   ├── attempts_ledger.md            ← ATT-N 跨轮意图汇总
│   ├── bitter_lessons.md             ← 项目技术踩坑(bs 太大 / 不兼容 等)
│   ├── successful_fixes.md           ← FIX-N 最终成功
│   ├── rule_violations.md            ← AI 行为错误(误判 cache / 跳 record / ...)
│   └── goal.md                       ← user 控制,AI 只读
├── .barry_workflow/                  ← per-session state(hook 自建)
│   ├── state_<sid>.md                ← 主 session 状态(hybrid yaml+md)
│   ├── action_<sid>.md               ← 主 session 原子流(record-before-op)
│   ├── reflection_<round_id>.md      ← rebuttal 实时文档(per reflect 实例)
│   └── agent_<agent_sid>/            ← 每个 subagent 自己的目录
│       ├── state.md
│       └── action.md
```

**subagent state**(Q7 答案 + 讨论)— subagent 也走 BOOT/PREPARE 简化版:

| 选项 | 描述 |
|------|------|
| A. subagent share 父 session | 简单,但 subagent 没"自己反思"的空间 |
| B. subagent 独立 state | 复杂,但 subagent 也能走 status 机制 |
| **C. hybrid(推荐)** | 用 subagent 自己的 session_id(若有)派生独立 state + action,但 BOOT 阶段从父 state 继承 `cache_hit_map` / `goal.md ref`,避免重新走 PREPARE |

**Subagent session_id 探测**(line 391 comment):需要测。Claude Code 给 subagent 派出时,subagent transcript 在 `~/.claude/projects/<slug>/<parent_sid>/subagents/agent-<aid>.jsonl`。`<aid>` 就是唯一 id,可作 state 目录名:`.barry_workflow/agent_<aid>/`。

**如果 subagent 没自己的独立 session_id**(待测试):用 `<aid>` 作目录;父 session hook 在派出后 1 sec 内 mkdir 这个目录。

---

## 4. State 文件 — hybrid 格式(Q3 答案)

```markdown
# Workflow State — session <sid> — 2026-05-13

```yaml
---YAML---
current_status: EXECUTE_LOOP
stage_history:
  - {name: BOOT,    completed_at: 2026-05-13T05:01Z, evidence: "router read"}
  - {name: PREPARE, completed_at: 2026-05-13T05:05Z, evidence: "cache_hit_map written"}
cache_hit_map:
  goal.md:           {hit: YES, last_read_turn: 42, sig: abc}
  attempts_ledger:   {hit: NO,  must_read: true}
  bitter_lessons:    {hit: YES, last_read_turn: 40}
reflection_history:
  - {reason: pre-task,    rounds: 3, consensus: true,  at: 2026-05-13T05:08Z}
fork_decisions: []
---YAML---
```

## Notes(主线程自由记)

...
```

Hook 用 Python `frontmatter` 或 `yq` 解析 YAML 区块;AI 直接读写整个 markdown,YAML 段用代码块包住不会被 AI 误改其他内容。

---

## 5. Codex 兼容性 — 工具对照分析(line 400 comment)

| Claude Code 能力 | Codex 对应? | 影响 |
|-----------------|-------------|------|
| hooks(UserPromptSubmit/PreToolUse/PostToolUse/Stop)| ✅ Codex 也有 hooks 系统(`set_codex.sh` 部署 ~/.codex/config.toml + hooks/) | 同步 hook 内容即可,逻辑通用 |
| Agent tool(run_in_background=true)| ⚠️ Codex 有 subagent 概念但 API 名字不同 | 需要 wrapper 抽象 spawn 接口 |
| SendMessage(发消息给 bg agent)| ⚠️ 不确定 — Codex 可能没等价 | **关键风险** — 没 SendMessage 则 rebuttal 在 Codex 上无法工作。fallback:让 Codex 走单向 ask 模式(轮询 markdown)|
| Monitor tool(读 bash_id 输出)| ⚠️ Codex 不一定有 | Codex 用 BashOutput / tail -f 替代 |
| 文件 Read/Write/Edit/Bash | ✅ 通用 | 无差异 |
| TaskCreate/TaskList/TaskStop | ⚠️ Codex 任务模型不同 | 用文件 + 标志替代 |
| KillBash | ⚠️ 不确定 | Codex 用 `kill <pid>` Bash |
| jq / yq / python3(state 解析)| ✅ shell 通用 | 无差异 |

**结论**:
- **核心机制(状态机 + KV cache + rebuttal 文件协议)工具无关** ✅
- **rebuttal 通信层**(SendMessage)是 Claude Code 专属,Codex 上需 fallback 到"主线程定时 poll markdown"(`while true; do sleep 30; read file; if 新内容; respond; fi`)
- **建议**: 先在 Claude Code 上跑通,跑顺后写 Codex 适配层(fallback poll 模式),不阻塞 v4 落地

---

## 6. 现有 hook 系统迁移路径(line 402 comment)

| 现有 hook | 命运 |
|-----------|------|
| `reset_session_status.sh`(UserPromptSubmit)| **复用 + 改造** — 改成"BOOT 时建 state_<sid>.md / action_<sid>.md;非首次 turn 加 turn marker;无 gate 重置(因为 v4 不用 gate)" |
| `stop_self_audit.sh`(Stop)| **删 或 大改** — Q8 答案 + line 406:Claude Code 有 `goal` hook 可替代 stop hook 的"任务未完不让停"。先调研 `goal` hook 文档,看能否完全取代;不能取代 → stop_self_audit 改成"只检查 state.current_status,若是 EXECUTE_LOOP / REFLECT 进行中则 block stop" |
| `inject_decrees.sh`(UserPromptSubmit + PostToolUse:Agent)| **改造** — 内容从 9KB Decrees 全文 → 1.5KB router 速查表 |
| `inject_decrees_to_subagent.sh`(PreToolUse:Agent)| **改造** — 注入 subagent_rules.md 路径而非全文;subagent 自己 Read |

**新增 hook**:
- `pretooluse_short_nudge.sh`(必做 #5)
- `posttooluse_state_transition.sh` — 监听 `transition.sh` 调用,更新 state 文件
- (可选)`session_start_init.sh` — 替代 init_corporal.sh 的功能,只建 per-session 目录

---

## 7. Demo 任务(line 404 comment)

**任务定义**:

> 下载一个 HF 上的开源模型(对当前 GPU 绰绰有余,推荐:`Qwen2.5-0.5B` 或 `Llama-3.2-1B`),部署 + 跑通推理。
> 下载 GSM8K benchmark **只跑前 100 题**(多了算错,因为要快)。
> 在模型中间某一层 hook activation,把答题输出 + 该层 activation **保存到本地**。
> 验收: **GPU + CPU 利用率,至少有一个吃满**(=100% 持续 ≥30s)才算 pass。

**为什么这个任务适合作 demo**:
- 涉及多 stage:setup(下载/部署)→ benchmark(跑 100 题)→ hook activation → save
- 涉及监控(GPU/CPU 利用率作主要 observable)
- 涉及 bug 可能性:模型 OOM / hook 写错层名 / activation tensor 太大爆磁盘 / GPU 利用率不够 → 必走 REFLECT (on-anomaly)
- 涉及完成判定:100 题答完 + 利用率达标 → REFLECT (post-task) 确认

**Observables**:
- `gpu_util`: `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader` / expected: ≥90% during inference / fail: <50% sustained 1min
- `cpu_util`: `top -bn1 | grep "Cpu(s)"` / expected: ≥50% / fail: <20% sustained 1min
- `at_least_one_full`: `gpu_util ≥ 99 OR cpu_util ≥ 95` 持续 30s → pass
- `progress`: `wc -l results.jsonl` / expected: 增长至 100 / fail: stuck
- `activation_files`: `ls -la activations/ | wc -l` / expected: 100 / fail: <100 at end

**用作 v4 P6 端到端 demo,跑全 BOOT/PREPARE/REFLECT/EXECUTE 5 status**

---

## 8. Stop hook 与 Claude Code `goal` hook(line 406 comment)

Commander 提到 Claude Code 有 `goal` hook(我未亲见文档,以 Commander 信息为准)。可能含义:

- `goal` hook 可能是个新的 user-defined hook 类型,触发条件类似"任务目标未完成则 block stop"
- 或者它是某种 "session-level goal" 字段,影响 stop 行为

**调研 + 决策**:
1. 首先 Commander 确认 `goal` hook 文档位置 / 行为(line 406 comment 说"我看看")
2. 若 `goal` hook 能监控 state.current_status,**完全代替 stop_self_audit.sh**:Claude Code 自己决定何时允许 stop
3. 若不能完全代替,stop_self_audit.sh 改造成"看 state.current_status,仅 BOOT/END 允许 stop"

**默认假设(待确认)**: 用 `goal` hook 替代,删 stop_self_audit.sh

---

## 9. Q1-Q8 答案落实清单

| Q | 答案 | 已写进 § |
|---|------|---------|
| Q1 subagent 编号 | 用 subagent session_id(若有)派生 `agent_<aid>/`;若无,父 hook 在派出后建 | § 3 |
| Q2 KV cache 信谁 | 信 AI 自报,失败入 `rule_violations.md` | § 2 Status 2 + § 3 边界 |
| Q3 state 格式 | hybrid markdown + YAML 区块 | § 4 |
| Q4 REFLECT 复用 | 通用 1 个 + reason 入参;失败调试 prompt;再失败请示 | 必做 #3 |
| Q5 rebuttal N | N=5 试 → 实测调,失败 fallback N=10 | 必做 #3 |
| Q6 EXECUTE 退出 | AI 自判(bug / 跑完) | § 2 Status 4 |
| Q7 subagent state | 独立 state,继承父 PREPARE 结果跳过自身 PREPARE | § 3 |
| Q8 Haiku/PreToolUse | Haiku 砍;PreToolUse 加回但只发**短提醒**(≤100 字) | 必做 #5 |

---

## 10. 落地优先级(更新)

| P | 工作 | 工时 |
|---|------|------|
| **P1** | 改名 + 去 cosplay(术语统一)+ 项目根重命名 | 2h |
| **P2** | 拆 rules/ + router + 收缩 inject 注入 | 2h |
| **P3** | state_<sid>.md 模板 + UserPromptSubmit 自建 hook(替 reset_session_status.sh) | 2h |
| **P4** | Status 1-2 跑通(BOOT + PREPARE + KV cache 自报) | 2h |
| **P5** | Status 4 EXECUTE_LOOP 显式约束 + AI 自判退出 | 2h |
| **P6** | Status 3 REFLECT — rebuttal 协议(SendMessage 主导)+ markdown 协议 | 4h |
| **P7** | PreToolUse 短提醒 hook(必做 #5) | 1h |
| **P8** | Demo 任务 P6 实跑(HF 模型 + 100 题 GSM8K + activation hook) | 4h |
| **P9** | Stop hook 调研 `goal` hook + 决策 | 1h(主要调研)|
| **P10** | Codex 适配层(rebuttal 用 poll 而非 SendMessage) | 待 P1-P9 跑顺再做 |

**P1-P9 合计 ~20h**(2-3 工作日)。

---

## 11. 已知风险

- **Codex 无 SendMessage**: rebuttal 在 Codex 上必须改单向 poll,可能不如 dialectic 有效
- **subagent session_id 探测**: 未实测,可能有 corner case
- **KV cache 信 AI**: AI 误判会写 `rule_violations.md`,但本身写 violation 也是 AI 行为 — 如果 AI 学到"反正能写 violation 就 OK",就成了**逆向激励**。对策:每 N 个 violation 用 PreToolUse 触发更严格审查模式
- **rebuttal 30s sleep + 重复 SendMessage 可能太慢**: 100 题 demo 跑下来如果 reflect 5 次,每次 5 轮 × 30s = 12.5min 反思开销。需要实测
- **`goal` hook 信息不全**: 等 Commander 提供文档,本 plan 假设它能替代 stop_self_audit

---

## 12. 总览(中性版)

```
┌────────────────────────────────────────────────────────────┐
│           barry-workflow v4 — State-Machine Pipeline       │
├────────────────────────────────────────────────────────────┤
│ ① rules 拆分: 1.5KB router + ~/.claude/rules/*.md 按需读   │
│ ② FSM 4 status: BOOT → PREPARE → REFLECT → EXECUTE_LOOP   │
│ ③ Rebuttal: 主线程 SendMessage 主导,subagent 写 markdown │
│ ④ KV cache: AI 自报,失败入 rule_violations.md            │
│ ⑤ PreToolUse 短提醒: ≤100 字 nudge,不污染 context       │
│                                                            │
│ 去 cosplay: 军事用语全替换,工件目录改 workspace/         │
│ 跨工具: Claude 全功能,Codex 用 poll 替代 SendMessage     │
│ Demo: Qwen2.5-0.5B + GSM8K-100 + activation hook         │
└────────────────────────────────────────────────────────────┘
```

要从 P1(改名 + 去 cosplay)起步吗?这个最先做能让后续所有计划都对齐。

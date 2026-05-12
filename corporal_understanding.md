# Corporal 对 Commander 编辑意图的理解（中文版）

数据来源：`workflow_spec.md`（358 行）+ `pipeline_state.json`（1020 行）+ Commander 后续口头补充（2026-05-12）。

每个主题列出 **删除项的具体内容** + **删除原因**，供 Commander 判断是否授权执行。

---

## 主题 1 — Hook 注入军令，朗读机制删除

### 要删的内容（来源：`content/CLAUDE.md`）

| 位置 | 原文摘要 | 删除原因 |
|------|---------|---------|
| 第 1-4 行（顶部第 1 个 ⚠️ 横幅） | 「MUST RECITE THE DECREES — verbatim — under any circumstances ×5」「**The first word of every reply must be `Decree`**」「Missing 1 character / wrong order = Treason」 | Hook 已经做了自动注入，AI 无需再口头朗读；首字 `Decree` 规则是为了强制朗读，现在朗读不需要了，也跟着删 |
| 第 88 行（## 1 4-Step Opening 的 Step 1） | 「Step 1 — Recite all Six Decrees verbatim... First word of reply must be `Decree`」 | 同上。4-Step Opening 变成 3-Step（删 Step 1，原 Step 2/3/4 顺延）|
| 第 100 行 | 「Missing any one of 1/2/3 steps = Dereliction of Duty」 | 步骤数量变了，文字要相应改成「Missing any one of the 3 steps」|
| 第 104 行 PC(0) 项 | 「(0) At the start of this turn did I **recite all Six Decrees verbatim**...」整段 | 朗读自检不需要了 |
| 第 108 行（## Key Decrees 标题旁） | 「Six — recite verbatim at the start of every reply; missing one character = violation of that turn」 | 标题旁的"必须朗读"附注 |
| 第 110 行 | 「Every single conversation must recite the Decrees!!!!!」 | 重复强调朗读，已无效 |
| 第 114 行 | 「Because of the primacy effect: rules at the beginning of long contexts take effect first (arXiv:2406.15981).」 | 这是支持"朗读放在开头"理由的论文引用，朗读没了就不需要 |
| 第 116 行（Decree 1 正文内） | 「**the first word of every reply must be `Decree` (opening the recitation of Decree 1)**, and until the recitation of all Six Decrees is complete, no other words may be spoken, no tools called, no response... Missing 1 character / wrong order / doing anything else first / abbreviating to numeral 'Decree 1' / abbreviating to title = Treason = execution.」 | 整段朗读规定 |
| 第 134 行（Identity section） | 「**Execution of identity rules depends on reciting all Six Decrees verbatim at the start of every conversation — not reciting = identity degradation fastest = first rule to collapse in long-context.**」 | "身份规则靠朗读维持"的逻辑链作废 |
| 第 189-194 行（End Restatement） | 「- Must recite Decrees verbatim! Must recite Decrees verbatim! Must recite Decrees verbatim! Next conversation opening first action = **recite all Six Decrees verbatim**...」 | 三连暴力提醒朗读 |
| 第 202 行（Final reminder） | 「Every conversation first action = recite all Six Decrees verbatim... **Recite Decrees + must dispatch + four-module reflection + 15-minute monitoring = four most important meta-rules**」 | 把"朗读"从四大元规则里去掉，剩三大 |

### 要删的内容（来源：`content/memory/soldier_protocol.md`）

| 位置 | 原文摘要 | 删除原因 |
|------|---------|---------|
| 第 80 行（Private 4-step 第 1 步） | 「Step 1: Recite Six Decrees verbatim (not simplified to numbers / not simplified to titles), first word must be `Decree`」 | 子代理也不再需要朗读（hook 通过 PreToolUse matcher=Agent 注入到 dispatch prompt） |

### 要新增的内容

- `hooks/inject_decrees.sh`（UserPromptSubmit + PostToolUse:Agent）：暴力重复 ×3 + 6 条军令完整原文 + Prompt Reinforcement 4-item kit
- `hooks/inject_decrees_to_subagent.sh`（PreToolUse matcher=Agent）：拦截 Agent 工具调用，向 `tool_input.prompt` 前置注入军令
- `~/.claude/settings.json`：注册以上两个 hook
- `set_claude.sh`：自动部署 hook + settings.json 幂等合并

---

## 主题 2 — REFLECT-A 升级为 6 条军令逐条自检表

### 来源
SCN-1 O3 节点（来自 spec）：
> "about recite part: delete, but make sure in here ai check if it follows all 6 rules. need to be sth like `rule1 yes/no [full complete reason]` ... `rule 6 ...`"

### 要改的内容（`content/CLAUDE.md` 第 122-126 行 + `soldier_protocol.md` 相应位置）

**原文（REFLECT-A 模块）**：
> [REFLECT-A Decree self-check] — Did the opening truly recite all Six Decrees verbatim (no abbreviation)? Were all three bulletin boards fully Read? Were any errors listed on the warning board repeated this turn? **Decree 2 (facts-first) — did every [INFERENCE] annotation in this turn trigger the "observation item upgrade + reflection" workflow...**

**改成**：
```
[REFLECT-A 六条军令逐条自检]

| Decree | Followed? | 完整理由（含证据） |
|--------|-----------|------------------|
| D1 Identity     | ✓/✗ | ... |
| D2 Facts-First  | ✓/✗ | ... 本轮 [INFERENCE] 是否触发了观察项升级？哪些？values？ |
| D3 Dispatch     | ✓/✗ | ... 本轮是否 >1 file/WebSearch/code？是否派遣？|
| D4 Recording    | ✓/✗ | ... 是否写 action.md？|
| D5 Reading      | ✓/✗ | ... 是否全部用 Read 工具？|
| D6 Workflow     | ✓/✗ | ... 是否有 fix-loop 进行中？是否所有 retest ✅？|

Plus: 是否完整 Read 公告板？是否有 warning_board 已列错误本轮重犯？
```

### 删除原因
原 REFLECT-A 是自由文本自问自答，AI 容易写空话敷衍。强制 6 行表格 + 每行需要 evidence，让审计可机器化，无处藏匿。

---

## 主题 3 — 记录文件体系重新设计

⚠️ **Commander 的关键修正**：之前我误以为是 5 合 1。**实际上应该是 5 个不同用途的文件**，各司其职。

### 五文件分工（基于 Commander 口述）

| 文件名（建议） | 记录粒度 | 内容 | 何时写 |
|--------------|---------|------|--------|
| **`operation_log.md`** | 操作粒度（不是 agent 微动作） | 「做了一件事就记一条」。例：修改了 yaml 中的 `lr` 字段、开启 torch compile、新增 `data.py` 文件。**只要做了事就记**，是流水账 | 每次做一个有意义的操作后立即记 |
| **`attempts_ledger.md`** | 尝试粒度 | 一次"为了解决 X 问题，我尝试 Y"的尝试记录，含 commit_id + before/after observation + 结论（worked / failed / partial / wrong-direction）。一次 attempt 可能含多个 operation_log 条目 | 每次完成一个尝试（无论成败）|
| **`bitter_lessons.md`** | 失败 efforts 的归档 | 做过但**失败**的努力。比单纯失败更详细：为什么失败、付出了多大代价、放弃的判据。Commander 之前以为已经写了这文件，**实际未创建** | 一个尝试失败并确认放弃后，归档到这里 |
| **`successful_fixes.md`**（或类似） | 重大成功修复 | 经过大量尝试后**真正修好** bug 的最终操作。每条对应一次重大胜利 | bug 真修复 + retest ✅ 后写入 |
| **`violation.md`** | AI 违规 | AI 自己违反军令的事件。和 bug / fix 不是一回事。例：忘记派遣、口头声明"我反思了"但没写、跳过 retest 等 | 检测到违规当即写入（同 Decree 4 三同步要求） |

### 现有要清理的文件

| 现有文件 | 处理方式 |
|---------|---------|
| `content/memory/violations.md` | 重命名 → `violation.md`（窄化语义为"AI 违规"，去掉里面的 bug-fix 历史；bug-fix 历史迁到 attempts/bitter） |
| `content/memory/lessons.md` | 拆分 → 成功 fix 迁入 `successful_fixes.md`；操作流水迁入 `operation_log.md` 模板 |
| `content/templates/warning_board.md` | 删除（功能已被 violation + bitter_lessons 取代）|
| `content/templates/reward_board.md` | 删除（功能已被 successful_fixes 取代）|
| `content/templates/traitor.md` | 删除（功能合并入 violation.md）|

### 删除原因（每个文件单独说）

- **warning_board.md**：原设计是"绊脚石提醒"，但实际功能等于 violation + bitter_lessons 子集，重复
- **reward_board.md**：原设计是"正面经验"，等于 successful_fixes，重复
- **traitor.md**：原设计是"叛徒名册"，等于 violation.md 详细版，重复

### 要改的 CLAUDE.md / soldier_protocol.md 内容

- 第 162-164 行 §4 Error Learning：重写五文件分工说明
- 第 87-96 行 Step 2 阅读列表：把 `warning_board` + `reward_board` 替换为 `violation.md` + `bitter_lessons.md` + `successful_fixes.md` + `attempts_ledger.md` + `operation_log.md`
- Decree 4 violation 三同步条款：从「action + warning_board + traitor」改成「action + violation.md」（两同步）
- `init_corporal.sh`：模板列表更新（删 3 创 5）

---

## 主题 4 — [INFERENCE] 证据化 + 二次反思

### 来源
SCN-7 INFERENCE & RESPOND（来自 spec） + Commander 后续补充：
> "证据话还要加一个reflection 就是inference他写出那么多证据了 再次reflect过了吗 确定是完整的证据了吗"

### 要改的内容（Decree 2 + REFLECT-A）

**改 Decree 2（`content/CLAUDE.md` 第 117 行）**：
- 现有：「[INFERENCE] can only be used after exhausting all observable variables」
- 加强为：「[INFERENCE] 使用必须满足两步」：
  1. **证据列表**（内嵌到 action.md 和 user-facing response）：
     - 已 WebSearch N 次（具体关键词）
     - 已 line-by-line Read 的文件清单（含 file:line ranges）
     - 已跑的实验（含命令 + 输出摘要）
     - 多轮自问自答（"也许我可以检查 X？哦不 X 已经查过了... 我确定再没别的可查"）
  2. **二次 meta-reflection**（新加）：把上面证据列表写完后，**再做一次反思**自问：
     - 这些证据真的完整了吗？
     - 还有没有别的可观测变量是我漏掉的？
     - 我是不是 [INFERENCE] 用得太早，没真正穷尽？
     - 写一段二次反思结论，再决定 [INFERENCE] 是否成立

**改 RESPOND 节点（不是单独文件，是工作流约束）**：
- 用户可见的回复里，[INFERENCE] 旁必须挂效力清单 + 二次反思摘要
- 不能只在 action.md 里写

### 删除原因
现状 [INFERENCE] 是个免责标签，AI 滥用 → 加证据化 + 二次反思，把成本提到 AI 不敢轻易标的程度。

---

## 主题 5 — Fix-loop retest 必须等真实结果

### 来源
SCN-4 / SCN-12 SC-RFLT（spec）：
> "make sure it shall check whether (if fixing sth) fix is done, do the test, rerun or sth to MAKE SURE NO FUCKING ANY MISTAKE"
> "have I really run the code wait untill I get the return/results making sure that's working????"

### 要改的内容（Decree 6 + REFLECT-C）

加 3 条强制问句到 fix-loop retest（`content/CLAUDE.md` 第 121 行 Decree 6 + REFLECT-C 文本）：

1. **我有没有真正跑测试命令？**（不是看代码"应该对"就声明）
2. **我有没有等到命令返回结果？**（不是 submit 完就走人）
3. **结果是否匹配 success criterion？**（不是"看起来 OK"——要写出 expected vs actual 对比）

不满足任一 → 不算 retest ✅ → 不能 hand back。

### 删除原因
现状 "fix ≠ resolved; retest passing = resolved" 这条规则存在，但 retest 内容定义太松，AI 经常写"我跑了测试通过了"但实际没等结果。

---

## 主题 6 — CronCreate 之后必须用 Monitor 验证任务真在运行

### 来源
SCN-3 CRON（spec）：
> "shall not just use this: ofc it first need to create cron, but also need to explicit let ai use monitor tool to make sure at lease code starts running not exit with bug or in the queue while later may exit."

### 要改的内容（Decree 3 / M4）

派遣后流程加一步（CLAUDE.md 第 26-30 行 Fourth Most Important Rule + Decree 3）：

派遣 → CronCreate `*/15` → **≤ 1 分钟用 Monitor / TaskList 验证**：
- 任务状态必须是 `running`（不是 `queued` / `exited` / `error` / 无记录）
- 失败 → 立即报告（不是等下次 cron 才发现）

可观测：`TaskList` 或 `Monitor` 工具输出的 status 字段。

### 删除原因
SLURM 等队列系统会显示"submitted"但任务可能因脚本错误立即退出。仅靠 CronCreate 不够。

---

## 主题 7 — 3 次失败 stop 规则的授权例外（基于项目 CLAUDE.md 实时读取）

### 来源
Commander 后续补充（推翻 spec 里的"loop 模式"模糊表述）：
> "loop授权失败这个有点模糊 改成阅读该项目下的CLAUDE.md 指挥官会事实修改这个 里面如果写了比如 allow you to do anything或者类似的东西就是授权了"

### 要改的内容（M6 + Decree 3 fix-loop 退出条件）

新增条款：

```
项目级 CLAUDE.md 实时授权机制：

每次发生连续失败时，必须 Read 该项目根目录下的 CLAUDE.md
（不是 ~/.claude/CLAUDE.md，是 $PWD/CLAUDE.md）。

如果发现以下任一模式 → 视为 Commander 已授权继续，3 次失败 stop 暂停：
- "allow you to do anything"
- "you have the authorization to keep trying"
- "no stop until X" 类的明示
- 其他 Commander 显式书写的全权授权

未发现授权 → 维持原规则（3 次失败必停 + 上报）。

发现授权时：
- 在 action.md 写 [AUTH_DETECTED] 条目，引用授权原文 + 时间戳
- 继续尝试时，每次失败附带"已发现授权 X，继续尝试 N"标识
- 但仍受其他规则约束（truthfulness / fix-loop retest 不能跳过）
```

### 删除原因
spec 里"loop mode"是个语义模糊的 enum；改用"读项目 CLAUDE.md"既具体（Commander 知道在哪写）又灵活（写法任意），且没有 enum 维护负担。

---

## 主题 8 — Subagent 双层规则继承（口述补充）

### 来源
SCN-1 PC0.5（spec）：
> "If dispatch, need to think how to let agent follows subagent rules. They have their own rules right? and shares some main rules as well"

### 要做的事

明确两层规则：

| 层 | 内容 | 谁继承 |
|----|------|--------|
| **共享核心层**（hook 注入） | 6 条军令 + 反思要求 + Prompt Reinforcement | 主线程 + 所有子代理 |
| **子代理专属层** | Iron Rules A-G（30 秒内首写、SILENCE_START/END、authorization 字段、不能再派子代理）| 仅子代理 |

实现：
- 共享层 → `hooks/inject_decrees.sh`（UserPromptSubmit + PostToolUse + PreToolUse:Agent 三处都注入）
- 子代理专属层 → `hooks/inject_decrees_to_subagent.sh`（仅 PreToolUse:Agent，在 prompt 前置 A-G 全文）

### 删除原因
现状 Iron Rules A-G 只在 dispatch prompt 模板里出现（main thread 手抄）。子代理不读 CLAUDE.md，全靠 main thread 自觉抄写——已被 W-XXX 反复证明不可靠。改成 hook 自动注入。

---

## 主题 9 — Prompt Reinforcement 工具化自动注入

### 来源
SCN-3 PRE_DISP（spec）：
> "I hope we can also use tool or sth to inject"

### 要做的事

`hooks/inject_decrees_to_subagent.sh`（即主题 8 同一个 hook）增加功能：

读取 `tool_input.prompt`，自动检测 4-item kit 关键词：
- `observable` / `measurement command`
- `monitor` / `cadence`
- `reflect` / `four-module`
- `complete` / `done criteria`

任一缺失 → 自动在 prompt 前置标准化补强模板（在 corporal_action.md 里附 [AUTO_REINFORCED] 痕迹）。

### 删除原因
手抄 `[PROMPT REINFORCED]` 3-item 已被 W-XXX 证明经常被跳过。自动化更可靠。

---

## 主题 10 — 弱 prompt 主体保留，但 [STOP] 节点 inheritance 上证据化（修正）

### 来源
SCN-10 STOP（spec）：
> "should be something like [inference] modification, which is: you shall show all the efforts in very precise details, both action file and response."

### 要做的事

STOP 节点共享主题 4 的证据化要求。停下来时同样要写完整 effort log：
- 跑了哪些命令、输出
- 读了哪些文件、line range
- 搜了几次、关键词
- 多轮自问自答历史

不能只说"我搞不定，求助"。

---

## SCN-2 待澄清

Spec 里 SCN-2 的 MODIFY 项是 `[TODO describe]` 占位，Commander 没填具体修改。**Corporal 不擅自推测，等 Commander 补充。**

---

## 关键决策点（Corporal 仍需 Commander 拍板）

1. **5 个文件的最终命名**：建议 `operation_log.md` / `attempts_ledger.md` / `bitter_lessons.md` / `successful_fixes.md` / `violation.md`——Commander 喜欢哪些名字？
没问题
2. **5 个文件存放位置**：建议全部在 `militar_camp/`（项目级），而不是 `content/memory/`（全局级）。因为这些是项目相关的工作历史。
AGENT violation 要放在全局级 你查一下我觉得不是content memory, claude默认的好像是 ~/.claude/memory或者 ~/.claude/rules 互联网搜一下

**Corporal 搜索结果（2026-05-12，已 verify）**：
- ✅ **`~/.claude/rules/`** ← Claude Code 全局规则目录，**会自动加载到每次 session 上下文中**，且在项目规则之前加载。源：https://code.claude.com/docs/en/memory
- ✅ **`~/.claude/projects/<project>/memory/`** ← 每个项目独立的 auto-memory 目录（按 git repo 派生），不是 violation 想要的全局
- 可选：通过 `~/.claude/settings.json` 的 `autoMemoryDirectory` 字段覆盖默认路径

**Corporal 推荐**：把 `violation.md` 放 **`~/.claude/rules/violation.md`**——理由：
1. Claude 自动每 session 加载，AI 启动就看到（不需要 Commander 在 prompt 里提醒）
2. 跨项目全局有效（任何 repo 都共享同一个 violation 历史）
3. AI 会"自然记住"过往违规

四个项目级文件（`operation_log` / `attempts_ledger` / `bitter_lessons` / `successful_fixes`）继续放 `militar_camp/`。

Sources: [Claude Memory Docs](https://code.claude.com/docs/en/memory) · [Anatomy of .claude/ folder](https://blog.dailydoseofds.com/p/anatomy-of-the-claude-folder)
3. **REFLECT-A 6 行表格**用 markdown 表格还是嵌套 checklist？建议表格便于审计。
markdown表格 
4. **Hook 输出字节预算**：当前 6 条军令 + 暴力重复 ≈ 3 KB；加 Prompt Reinforcement 模板 ≈ +1.5 KB；总计 ~4.5 KB，离 10 KB 上限还远，安全。
可以
5. **项目级 CLAUDE.md 不存在时**怎么办？建议：不存在 → 视为无授权 → 走默认 3 次停止规则。
不会不存在 不要考虑这个情况
6. **`saveHTML()` bug 是否一起修**？建议下次重做时一并修（替换 `fetch()` 为 `document.documentElement.outerHTML`）。
可以修一下 然后给我正确的html 之前的我点击了没有用

**已修复（2026-05-12）**：`pipeline_visualization_v2.html` 中 `saveHTML()` 改为：
1. 先 `document.getElementById("state-init").textContent = JSON.stringify(STATE)` 把当前 STATE 写回 DOM
2. 再用 `document.documentElement.outerHTML` 抓 live DOM（不用 fetch，规避 file:// CORS）
3. 前置 `<!doctype html>\n` 因为 outerHTML 不含 doctype
4. 触发下载

请 Commander 用更新版 `pipeline_visualization_v2.html`（55 行变更，文件略大），重新编辑 + 点 `💾 Save HTML w/ State`，下载的 HTML 应真正带 state。

---

## 完整性自检

| Pipeline | Spec 里的编辑 | 已纳入本文 |
|----------|------------|----------|
| SCN-1 | DROP O1; MODIFY USER_MSG/M1/PC0.5; KEEP O3 改写 | ✅ 主题 1/2/8 |
| SCN-2 | MODIFY NEW_REPO/O1/O3（占位）| ⚠️ 待 Commander 补 |
| SCN-3 | MODIFY USER_MSG/O1/PRE_DISP/CRON | ✅ 主题 1/6/9 |
| SCN-4 | MODIFY M1/SC-RFLT | ✅ 主题 1/5 |
| SCN-5 | MODIFY M1 | ✅ 主题 1 |
| SCN-6 | KEEP all | ✅ 无变 |
| SCN-7 | MODIFY INFERENCE/RESPOND | ✅ 主题 4 |
| SCN-8 | MODIFY VL/TR/LS/RESPOND + 新边 | ✅ 主题 3 |
| SCN-9 | KEEP all | ✅ 无变 |
| SCN-10 | MODIFY ASK_CMD/STOP | ✅ 主题 7/10 |
| SCN-11 | KEEP all | ✅ 无变 |
| SCN-12 | MODIFY SC-RFLT, FL-2 注释 | ✅ 主题 5 |

外加 Commander 口述 4 项重要补充：
- 5 文件分工（主题 3 修订）
- [INFERENCE] 二次反思（主题 4 修订）
- 项目级 CLAUDE.md 授权机制（主题 7 修订）
- bitter_lessons.md Commander 以为写过但未创建（指出事实）

---

**请 Commander 看完逐条决定**：哪些 Theme 现在授权 Corporal 做 / 哪些再调整 / 哪些先搁置。

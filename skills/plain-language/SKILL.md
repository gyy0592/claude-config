---
name: plain-language
description: "Enforces just-in-time term definition in technical writing — every name / file path / acronym / black-box term gets explained the moment it first appears (one line, parenthetical, inline), and re-explained whenever it reappears after a long gap. **NEVER** front-load a glossary at the top of a document; **NEVER** assume the reader has already read 100 turns of context. Trigger this skill aggressively whenever (1) the user complains 'I don't understand / 听不懂 / 说人话 / 给我说人话 / 你在说啥 / 这是啥 / 黑话 / 别用术语 / 操你妈的看不懂', (2) the user pushes back on a previous reply with 'what is X' / 'what does X mean' / '这个 X 是什么', (3) you're writing any technical report / diagnosis / plan / postmortem / architecture doc that mentions internal file paths, scripts, hooks, FSM states, variable names, or any term that wasn't in the user's original prompt verbatim, (4) you're about to write a 'Glossary' or 'Definitions' section at the top of a document — STOP, this skill says don't. Over-trigger rather than under-trigger; the cost of one extra inline definition is far lower than the cost of one user rage."
---

# plain-language — 即时定义、绝不预堆

## 这个 skill 在解决什么问题

写技术文档时常见的坏写法是：

- 在文档最上方堆一个 "## Terminology" 段，把 20 个术语一次性讲完，然后下面用术语时不再解释
- 假设读者记得 50 行前的那个定义
- 用 `posttool_state_reinforce.sh` 这种 black-box 文件名 / `STATUS=REFLECT` 这种 black-box 变量名 / `step 1-7 sequence` 这种 black-box 引用，**不告诉读者这个东西是干嘛的、在哪里、谁在用、什么时候会发生**

读者（包括气头上的用户）会觉得"全是黑话 / 你他妈在说什么"。

## 两条核心规则

### 规则 1 — Adjacent Definition（紧贴定义）

**第一次提到任何非通用名词时，就在同一句或下一句给定义**。不要预先在文档顶部 glossary。

可以是 4 种形态之一：

1. **行内括号注**：写 `用 jsonschema（Python 的一个 JSON 校验库）做校验`
2. **同句解释**：写 `posttool_state_reinforce.sh —— 一个挂在 PostToolUse 的 hook 脚本，每 10k token 注一段当前 state 的提示`
3. **第一次出现时单独一段**："`reflection_*.md` 是个文件，路径在 `.barry_workflow/<session-id>/`，AI 在 REFLECT 阶段往里写问题，subagent 往里写回复。"
4. **示例形态**：`这种情况下用 STATUS=REFLECT（比如 state.md 里写 current_status: REFLECT）`

判断什么需要定义的简单标准：**如果这个词不在用户原 prompt 里、也不是 Python/git/Linux 等通用基础概念，那就需要定义**。文件名、脚本名、内部状态名、环境变量名、自定义 schema 字段名——全部需要。

### 规则 2 — Re-recall on Distance（远了重新提醒）

如果一个术语**距离上次定义超过约 30 行**，或者在新章节首次出现，或者在不同 fail mode / 不同 phase 里再次出现——**重新给一句简短的提醒**，哪怕只是括号注一行。

判断标准：写每一段时，问自己"读者从这一段开始往回翻 30 行能找到上次定义吗？"。找不到就重提一句。

提醒不需要完整定义，可以是 mini 版：

- 上次完整说："`transition.sh` 是 `hooks/transition.sh`，AI 用 `bash hooks/transition.sh BOOT_DONE` 切 state"
- 30 行后再用时：写 "transition.sh（state 切换脚本）"——加个括号 mini 注就够

## 反面例子 vs 正面例子

### 反面 1 —— glossary 上来一锅烩

```markdown
# 术语
- FSM: ...
- transition.sh: ...
- state.md: ...
- router_BOOT.md: ...

# 第 1 章 (50 行后)
... posttool_state_reinforce.sh 在 STATUS=REFLECT 且 reviewer reply 为空时
注入 reflect.md 前 800 字符而不是 router 头 400 字符 ...
```

读者读到第 1 章这一句时，要回翻 50 行去对照每个术语 → 直接放弃理解。

### 正面 1 —— 紧贴定义

```markdown
# 第 1 章
... 修复方向：让 `posttool_state_reinforce.sh`（一个 v2.5 新加的 PostToolUse hook，
每 10k token 触发一次往 AI 上下文注一段提醒）的行为改一下。

具体规则：当 state.md 里写着 `current_status: REFLECT` 而且当前 session 目录下
最新那个 `reflection_*.md` 文件里 `## reviewer reply` 段还是空的（意思是 AI 派
出去的 rebuttal subagent 还没写回复），那么这个 hook 应该注入 reflect.md
（REFLECT 阶段完整流程文档）前 800 字符（覆盖 step 1-7 的具体 sequence），
而不是注入 router_REFLECT.md（短版状态提示）头部 400 字符。

例子：AI 刚 Write 了一个 `reflection_r1-...md` 占位文件，但 subagent 还没派出去，
所以文件里 reply 段是空的。下次 AI 调任何工具，PostToolUse 触发，hook 看到
"REFLECT + reply 空" 这个组合，于是注入完整 protocol step 1-7 让 AI 知道
下一步该 `Agent(...)` 派 subagent，而不是猜。
```

读者读到第一句就知道每个名词指什么、为什么这个改动 makes sense。

### 反面 2 —— "step 1-7 sequence"

```markdown
... 注入 reflect.md 前 800 字符（或 step 1-7 sequence）...
```

读者：什么 step 1-7？哪里的 step？

### 正面 2 —— 把 "step 1-7" 解释清楚

```markdown
... 注入 `content/rules/states/reflect.md` 前 800 字符。这段覆盖 protocol 的
完整 7 步流程（main 创建 reflection 文件 → 填问题 → spawn subagent → subagent
读文件写回复 → main 看回复决定继续或 CONSENSUS → ...），AI 读完知道下一步具体该做什么。
```

## 决策清单（写每段前自检）

每写完一段，扫一遍：

1. 这段里出现的每个非通用名词，**在这段之内或紧贴的上一段**有定义吗？
2. 这段出现的术语，**距离上次完整定义超过 30 行**了吗？是的话有没有给 mini 重提？
3. 这段有没有引用某个抽象编号 / 步骤号 / 章节号（"step 1-7" / "phase 3" / "P0" / "F4"）？引用的那个东西**在文档前文有定义吗**？没有的话能不能一句话讲清？
4. **预堆术语区**：这段是不是在文档前 20% 位置、且包含 5+ 个连续定义？是的话把这些定义打散到第一次出现的位置去。

任何一条答 "no"，立刻就改。

## 什么时候这个 skill 应当强力触发

- 用户说"听不懂 / 这是啥 / 别用术语 / 说人话 / 给我例子 / 黑话 / 看不懂 / 操你妈的"——立即触发，重写当前段。
- 在写任何 `docs/*.md` / `*_plan.md` / `*_audit.md` / 任何技术报告时——主动触发，每个内部术语都加 adjacent definition。
- 写代码 review / postmortem / failure analysis 类文档时——更要触发，因为这种文档的读者通常是没在第一现场的用户。
- 在写**给非作者本人看**的任何文档时（即 99% 情况）。

## 什么时候可以不用这个 skill

- 写代码本身（注释除外）——代码里术语对码农透明。
- 写跟用户对话的回复时（用户在现场，能立刻问追问）——但**用户一旦表示不懂，立刻进入本 skill 模式**。
- 给自己留草稿 / scratch notes——读者就是自己。

## 触发后的具体动作

1. 把文档顶部任何 "术语 / 定义 / Glossary / Terminology" 整段**删掉**（保留内容，散到第一次使用位置）。
2. 文档从头扫一遍，找出每个非通用名词的第一次出现位置，紧贴它加 adjacent definition。
3. 文档再从头扫一遍，找出每个术语**第二次以后**的出现位置，如果距离上次定义 > 30 行，加一行 mini 重提。
4. 写新内容时，每段写完先按"决策清单"自检一次再继续下一段。

## 一句话总结

**别让读者翻页找定义。每个新词就地解释；远了重提一次；预堆 glossary 即垃圾。**

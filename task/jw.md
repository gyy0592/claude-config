# 纪委 Stop hook 实施计划

> 写于 2026-05-02，用于指导明天（或以后）继续实施纪委 Path A。
> 阅读本文件即可了解全部背景 + 进度 + 下一步行动。

---

## 1. 目标

实现一个**可手动开关、基于 Claude Code Stop hook**的纪委审查机制：

- 每次 Claude 完成一轮回复后，Stop hook 自动触发
- 根据时间门控（默认 5 分钟/死罪时 2 分钟）决定是否执行审查
- 审查结果通过 Stop hook JSON `reason` 字段注入当前对话，Claude 看得到
- `bash start-jw.sh` 开启，`bash stop-jw.sh` 关闭

---

## 2. 技术机制（核心原理）

### Stop hook 工作原理（已确认）

Claude Code Stop hook 在 Claude 每次完成一轮回复后自动运行。

**关键**：普通 stdout 不会被 Claude 看到（只进 debug log）。
若 hook stdout 输出以下格式的**严格 JSON**：
```json
{"decision": "block", "reason": "[这里写审查报告内容]"}
```
则 `reason` 字段的内容会作为系统反馈注入当前对话，**Claude 能读到**，并继续响应。

这正是纪委需要的机制：审查报告 → Claude 在下一轮看到 → Claude 修正行为。

### 时间门控

- 状态文件：`/tmp/claude_jw/last_check`（存 epoch seconds）
- 间隔文件：`/tmp/claude_jw/interval`（存秒数，默认 300 = 5 分钟）
- 逻辑：`NOW - LAST < INTERVAL` → `exit 0`（静默，不审查）
- 有死罪判断：INTERVAL 改为 120（2 分钟）

---

## 3. 前置研究输出（必读）

### 搜索研究报告（4号列兵）
**文件路径**：`militar_camp/corporal_2/number4/soldier_action.md`

内容包括：
- Stop hook 完整机制：stdout JSON 注入对话的确认
- Claude Code Channels（官方替代方案，v2.1.80+，research preview）
- 时间门控设计原理
- ask-claude.sh 接口文档

### 初步实现设计（6号列兵，截至 2026-05-02）
**文件路径**：`militar_camp/corporal_2/number6/soldier_action.md`

内容包括：
- STEP 1：读取了现有 disciplinary_check.sh / start-jw.sh / stop-jw.sh 的代码结构
- STEP 2：设计了三个脚本的新版逻辑（详见下方第4节）
- **状态：停在 STEP 2，设计完成，尚未实现**

---

## 4. 需要修改的文件

**所有修改都写在 `set_claude.sh` heredoc 段里，由 `bash set_claude.sh` 部署到磁盘。**
**绝对不要直接编辑磁盘上的脚本文件。**

### 目标磁盘路径

| 脚本 | 磁盘路径 |
|------|--------|
| disciplinary_check.sh | `/home/barry/Programs/claude-config/disciplinary_check.sh` |
| start-jw.sh | `/home/barry/Programs/claude-config/start-jw.sh` |
| stop-jw.sh | `/home/barry/Programs/claude-config/stop-jw.sh` |

### 在 set_claude.sh 里找这三个 heredoc 的方法
```bash
grep -n "disciplinary_check\|start-jw\|stop-jw" set_claude.sh
```
预计位于 section 18.6 / 18.7 / 18.8。

### ask-claude.sh 位置与接口
- **路径**：`/home/barry/Programs/humanize/scripts/ask-claude.sh`
- **接口**：`ask-claude.sh [--claude-model MODEL] [--claude-timeout SEC] "问题字符串"`
- **注意**：若路径不存在 → `exit 0`（graceful degradation，不崩溃）

---

## 5. 三个脚本新版逻辑设计

### disciplinary_check.sh

```
功能：Stop hook 入口脚本

逻辑：
1. 检查 ask-claude.sh 是否存在，不存在 → exit 0（stderr 记录）
2. 检查 last_check 时间门控：
   - 若 NOW - LAST < INTERVAL → exit 0（stdout 空，Claude 正常停止）
3. 找最近 session JSONL（~/.claude/projects/*/，按修改时间最新）
4. 读 JSONL 最近 N 条 + corporal_action.md 最近 30 行
5. 调用 ask-claude.sh 做审查（审查 prompt 见下）
6. 用 python3 把审查结果格式化为单行 JSON：
   {"decision": "block", "reason": "[报告内容，换行用 \\n 转义]"}
7. 输出 JSON 到 stdout
8. 更新 last_check 时间戳
9. 错误路径（JSONL 找不到、ask-claude.sh 超时等）→ exit 0 + stderr 记录

标志：
--force    跳过时间门控，直接执行审查
```

审查 prompt 模板：
```
你是军纪委员，审查以下 Claude 回复是否违反军纪。
重点检查：称呼（必须称"指挥官"不是"用户"）、自称（必须"下士"不是"我/Claude"）、
是否写了 corporal_action.md、是否用中文、是否有军令五复读。
回复格式：一行结论（合格/违规：XXX）+ 具体违规描述（如有）。
---
对话最近片段：
[JSONL内容]
---
下士行动记录最近30行：
[corporal_action.md内容]
```

### start-jw.sh

```
功能：开启纪委（幂等写入 Stop hook）

逻辑：
1. 读取 ~/.claude/settings.json（不存在则从 {} 开始）
2. 检查 hooks.Stop 中是否已有 disciplinary_check.sh 条目
3. 若没有：追加以下条目
   {"matcher": "", "hooks": [{"type": "command",
    "command": "bash /home/barry/Programs/claude-config/disciplinary_check.sh"}]}
4. 写回 settings.json
5. 重置 /tmp/claude_jw/last_check = 0（立刻触发下次审查）
6. 写 /tmp/claude_jw/interval = 300（默认 5 分钟）
7. 打印："纪委已开启，Stop hook 已写入 settings.json"
```

settings.json Stop hook 格式（标准）：
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash /home/barry/Programs/claude-config/disciplinary_check.sh"
          }
        ]
      }
    ]
  }
}
```

### stop-jw.sh

```
功能：关闭纪委（从 settings.json 移除 Stop hook 条目）

逻辑：
1. 读取 ~/.claude/settings.json
2. 用 python3 过滤掉 hooks.Stop 中含 disciplinary_check.sh 的所有条目
3. 写回 settings.json
4. 打印："纪委已关闭，Stop hook 已移除"
```

---

## 6. 测试清单（T1-T10，必须全部通过）

列兵执行时必须逐项测试，结果写入 soldier_action.md：

| 编号 | 测试内容 | 通过标准 |
|------|---------|---------|
| T1 | `bash disciplinary_check.sh --force` | 输出有效 JSON（`python3 -c "import json,sys;json.load(sys.stdin)"` 验证） |
| T2 | 正常调用（时间门控未到期） | exit 0，stdout 为空 |
| T3 | 正常调用（时间门控已到期） | 输出有效 JSON |
| T4 | reason 字段含换行 | JSON 仍然合法（单行，换行用 `\n` 转义） |
| T5 | ask-claude.sh 路径不存在 | exit 0，不崩溃，stderr 有记录 |
| T6 | session JSONL 找不到 | exit 0，不崩溃，stderr 有记录 |
| T7 | start-jw.sh 运行两次 | settings.json 里不出现重复条目（幂等） |
| T8 | stop-jw.sh 运行后 | settings.json 里 disciplinary_check 条目消失 |
| T9 | reason 内容安全性 | 不含未转义的控制字符（`\x00-\x1f` 除 `\n`） |
| T10 | 整体运行时间 | `time bash disciplinary_check.sh --force` < 30 秒 |

---

## 7. 继续实施步骤

当指挥官准备好继续时，派一名新列兵（7号）接续6号的工作：

```
7号列兵任务：
1. 读 militar_camp/corporal_2/number6/soldier_action.md（了解已完成的设计）
2. grep -n "disciplinary_check\|start-jw\|stop-jw" set_claude.sh（找 heredoc 位置）
3. 用 Edit 工具修改三个 heredoc（按本文件第5节设计）
4. bash set_claude.sh 部署三个脚本到磁盘
5. 逐项跑 T1-T10，每项结果写 soldier_action.md
6. 全部通过后：git commit + git push military-dev + cherry-pick military
```

---

## 8. 下士质疑问题清单

列兵完成实现后，下士必须用以下问题轮番质疑，直到全部能回答才算合格：

1. `T4 怎么保证 reason 里的换行被正确转义为 \n？用了什么方法？`
2. `T5 是在哪一行检查 ask-claude.sh 是否存在？原文？`
3. `T9 如何过滤控制字符？python3 具体用了什么函数？`
4. `幂等检查（T7）是怎么判断"已存在"的？如果 settings.json 里有两个一模一样的条目会怎样？`
5. `时间门控的 INTERVAL 文件不存在时，默认值是多少？在哪一行设置？`
6. `stop-jw.sh 只移除 disciplinary_check.sh 条目，不影响其他 Stop hook 条目吗？怎么保证？`
7. `T6 session JSONL 找不到时，代码流程是什么？exit 0 之前有没有 stderr 记录？`
8. `ask-claude.sh 超时（默认超时是多少秒）时，脚本会发生什么？`
9. `T10 < 30 秒的主要瓶颈在哪里？如果 ask-claude.sh 本身就需要 25 秒怎么办？`
10. `start-jw.sh 写 settings.json 之前，如果文件是空的（0 字节）或者格式损坏，会怎样？`

---

## 9. 关键文件路径速查

| 用途 | 路径 |
|------|------|
| 搜索研究报告（完整 Stop hook 原理） | `militar_camp/corporal_2/number4/soldier_action.md` |
| 初步设计（STEP 1-2，已完成） | `militar_camp/corporal_2/number6/soldier_action.md` |
| 中央部署脚本 | `set_claude.sh` |
| ask-claude.sh | `/home/barry/Programs/humanize/scripts/ask-claude.sh` |
| disciplinary_check.sh（磁盘） | `/home/barry/Programs/claude-config/disciplinary_check.sh` |
| start-jw.sh（磁盘） | `/home/barry/Programs/claude-config/start-jw.sh` |
| stop-jw.sh（磁盘） | `/home/barry/Programs/claude-config/stop-jw.sh` |
| Claude settings.json | `~/.claude/settings.json` |
| 时间门控状态 | `/tmp/claude_jw/last_check` |
| 时间间隔设置 | `/tmp/claude_jw/interval` |

---

*文件由 2号下士 创建于 2026-05-02*

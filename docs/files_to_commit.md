# files_to_commit.md — v2 → main 同步清单

> 用途：开发期间持续记录「哪些 v2 改动是 main 应该拿到的」，避免下次推 main 时再做一次全量分类。
> 更新规则：每次在 v2 上做完一组改动，回到这里 append 一行到「待推 (Pending)」表格。推完 main 后挪到「已推 (Pushed)」段并记 commit hash。

---

## 推送原则（每次推 main 都要遵守）

### ✅ 允许推
- 公开可读的代码：`hooks/`, `scripts/`, `viewer/`, `archive/`
- 通用规则文档：`content/CLAUDE.md`, `content/rules/`, `content/templates/`
- 项目根 README（中/英）
- `.gitignore`、`set_claude.sh` 类部署脚本（去敏后）

### ❌ 禁止推
- `docs/*` 全部（内部 plan / 设计讨论 / e2e notes / system_overview / 本文件本身）
- `.barry_workflow_temp/*`、`.claude_status/*`、`workspace/*`
- `content/AGENTS.md` + `content/memory/*` —— v1 cosplay (Decree/Treason/Corporal/military_camp)，违 v4「no roleplay terminology」
- `content/CLAUDE.md.v1-bak` —— 备份
- 个人脚本：`jw-capture-session.sh`, `start-jw.sh`, `stop-jw.sh`, `set_codex.sh`, `set_monitor_time.sh`, `set_tg.sh`, `make_release.sh`（打包 v1）
- 任何 draft：`todo.md`, `v2_plan.md`, `workflow_spec.md`, `truthfulness_protocol_prompt.md`

### ❌ 禁止动 main 已有的
- `ten_commandments_for_ai_coding.md`
- `ten_commandments_for_ai_coding.zh.md`
- v2 已删除的（如果出现在 v2 里被 D 标记）—— 不要把删除应用到 main

### 敏感词扫描（push 前必跑）
```bash
git diff --cached | grep -nE "Barry|awesome-gpu|LLM_sampling|/home/yguo173|gyy0592"
# 必须输出为空
```

---

## 推 main 的标准流程

```bash
git fetch origin main
git checkout -b merge-to-main origin/main
# 按清单逐个 cherry：
git checkout v2 -- <file1> <file2> ...
# 敏感词扫描
git diff --cached | grep -nE "Barry|awesome-gpu|LLM_sampling|/home/yguo173|gyy0592"
# ten_commandments 仍在
git ls-tree HEAD ten_commandments_for_ai_coding.md ten_commandments_for_ai_coding.zh.md
git commit -m "sync v2 → main: <summary>"
git push origin merge-to-main:main
git checkout v2
git branch -D merge-to-main
```

---

## 待推 (Pending)

| 日期 | v2 commit | 文件 | 说明 |
|---|---|---|---|
| 2026-05-14 | (本次) | hooks/transition.sh, content/CLAUDE.md, content/rules/router_*.md (含新 router_RECORDING.md), content/rules/states/*.md (含新 recording.md), content/templates/state_template.md, content/templates/action_template.md, README.md, README.en.md | v2.4: 引入 RECORDING + END state；EXECUTE_EXIT → RECORDING 强制经过；NEED_RECORD/BACK_TO_LOOP/RECORD_DONE 三个新事件；state.md 加 prev_status 字段 |

> Append 新条目时格式：`| YYYY-MM-DD | <short-hash> | path/to/file.md | 一句话改动说明 |`

---

## 已推 (Pushed)

| 日期 | main commit | v2 commit 范围 | 内容 |
|---|---|---|---|
| 2026-05-14 | `c57f253` | `2b79a7f..a27683e` | shared workspace ledgers + viewer metrics + RESET_TO_BOOT + archive/stop_self_audit |
| 2026-05-13 | `461b94a` | 同期 | README quickstart: AI-conversational default; manual route optional |
| 2026-05-13 | `6a1e8ee` | 同期 | scripts/new_task.sh + CLAUDE.md pointer |

---

## 已知遗留（v2 上有但永远不推 main）

> 这些文件只在 v2 演进，main 永远拿不到。新写的同类放这里也行，免得每次重新判断。

- 全部 `docs/*.md` 和 `docs/*.html`
- 全部 `.barry_workflow_temp/*`、`.claude_status/*`、`workspace/*`
- `content/AGENTS.md`、`content/memory/*.md`、`content/CLAUDE.md.v1-bak`
- 根目录的：`todo.md`、`v2_plan.md`、`workflow_spec.md`、`truthfulness_protocol_prompt.md`、`jw-*.sh`、`set_codex.sh`、`set_monitor_time.sh`、`set_tg.sh`、`make_release.sh`

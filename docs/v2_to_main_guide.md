# v2 → main 分支管理指南

## 背景

| 分支 | 用途 |
|------|------|
| `v2` | 开发分支。所有新功能、实验性改动、viewer 开发都在这里 |
| `main` | 稳定分支。只包含已验证的、可以部署到生产环境的内容 |

两个分支之间**不用 merge**，用 **cherry-pick** 单独挑选 commit。这样 main 不会被带入 v2 的实验性内容。

---

## ✅ 应该 cherry-pick 到 main 的内容

这些是"行为规则"层——影响 AI 如何运作的核心文件：

| 路径 | 说明 |
|------|------|
| `hooks/*.sh` | FSM 状态机执行层（transition.sh、stop hook、session_boot 等） |
| `content/CLAUDE.md` | 主规则文件（BOOT 时注入给 AI） |
| `content/rules/*.md` | 各状态规则、patches、workflow_config.yaml |
| `content/templates/global_rules/*.md` | lessons.md、violation.md（跨项目智慧） |
| `content/templates/goal.md` | goal.md 模板 |
| `AGENTS.md` | 全局身份声明（Codex 用） |
| `set_codex.sh` / `set_claude.sh` | 部署脚本 |
| `scripts/*.py` / `scripts/*.sh` | 工具脚本（extract_transcript.py、new_task.sh 等） |

**判断标准**：这个改动是否会改变 AI 在任意项目中的行为？如果是 → cherry-pick 到 main。

---

## ❌ 不应该 cherry-pick 到 main 的内容

| 路径 | 原因 |
|------|------|
| `viewer/` | 开发调试工具，不是核心规则；main 不需要 viewer |
| `workspace/` | 项目级数据（ledgers、goal.md），每个项目各自维护 |
| `.barry_workflow/` | 会话状态文件，纯运行时产物 |
| `docs/` | 开发笔记、分析文档、可视化 HTML（不影响 AI 行为） |
| `scripts/barry_ipc.py` | Codex 专用实验脚本，main 不部署 Codex 路径 |
| 任何带 `WIP` / `experimental` 标记的 commit | 等稳定后再 cherry-pick |

---

## 操作流程

### 每次在 v2 完成一个功能后：

```bash
# 1. 在 v2 上 commit（已完成）
git log --oneline v2 | head -3   # 确认 commit hash

# 2. 切到 main，cherry-pick
git checkout main
git cherry-pick <commit-hash>

# 3. 如果有冲突（viewer/ 等 main 没有的目录）：
git checkout --theirs -- viewer/   # 保留 main 的版本（即不引入 viewer）
git add viewer/
git cherry-pick --continue

# 4. push
git push origin main
git checkout v2   # 回到开发分支
```

### 批量 cherry-pick（v2 有多个 commit 超前 main）：

```bash
# 找到分叉点
git log --oneline main..v2   # 看哪些 commit 还没在 main

# 从最老到最新逐个 cherry-pick（避免冲突累积）
git checkout main
git cherry-pick <oldest-hash> <next-hash> ... <newest-hash>
```

---

## 常见情况判断

**Q: viewer 改了样式/布局，要 push 到 main 吗？**
A: 不需要。viewer 是本地调试工具，main 部署的是 hooks + rules，不包含 viewer。

**Q: stop hook 改了逻辑（如 v2.7.6 把 haiku 换成 self-reflect），要 push 吗？**
A: 是。hooks/stop_bg_aware.sh 是行为规则层，cherry-pick 到 main。

**Q: content/rules/ 里的规则文件改了，要 push 吗？**
A: 是。这些文件会被 set_codex.sh 部署到 ~/.claude/rules/，是 AI 行为的核心。

**Q: workspace/v276/goal.md 这种文件要 push 到 main 吗？**
A: 不需要。workspace/ 是项目级文件，只属于当前 repo，不 cherry-pick。

**Q: CLAUDE.md（项目根目录的那个，不是 content/CLAUDE.md）要 push 吗？**
A: 看情况。根目录 CLAUDE.md 是项目专属指令，如果是通用的（比如 set_claude.sh 的说明）就 cherry-pick；如果是项目专属内容就不 cherry-pick。

---

## 远端部署（awesome-gpu-name）

cherry-pick + push 到 main 之后，还需要在远端拉取并重新运行 set_claude.sh：

```bash
ssh awesome-gpu-name "cd ~/Programs/claude-config && git pull origin main && bash set_codex.sh"
```

如果 viewer 也要更新（viewer 改动 cherry-pick 到 main 了），还需要重启 viewer_server.py。

---

*最后更新：2026-05-16，v2.7.6 session*

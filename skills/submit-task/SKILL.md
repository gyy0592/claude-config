---
name: submit-task
description: "Guides AI through the end-to-end task submission workflow for the claude-config repo: (1) initializing a task workspace with new_task.sh, (2) committing and pushing to v2 and main branches, (3) deploying to the remote GPU server via ssh. Trigger when user says 'submit', 'push', 'deploy', 'version bump', 'push to main', or asks to commit and push changes to this repo."
---

# submit-task — 任务提交与部署流程

## Step 1 — 创建任务 workspace（如果还没有）

```bash
bash /home/yguo173/Programs/claude-config/scripts/new_task.sh \
  --name <task_name> \
  --goal "..." \
  --constraint "..."
```

如果 `new_task.sh` 已在 PATH（运行过 `set_claude.sh`）：
```bash
new_task.sh --name <task_name> --goal "..." --constraint "..."
```

## Step 2 — 版本号更新（如果是新 release）

- 更新 `hooks/stop_bg_aware.sh` 第 2 行 `# stop_bg_aware.sh — v2.X.Y` 的版本号
- 不需要单独的 VERSION 文件

## Step 3 — Commit

```bash
cd /home/yguo173/Programs/claude-config
git add -p   # 或 git add <specific files>
git commit -m "v2.X.Y: <one-line description>"
```

## Step 4 — Push 到 v2 分支

```bash
git push origin v2
```

## Step 5 — Merge 到 main 并 push

```bash
git checkout main
git merge v2
git push origin main
git checkout v2   # 回到工作分支
```

## Step 6 — 部署到远端服务器

```bash
ssh awesome-gpu-name "cd /path/to/claude-config && git pull && bash set_claude.sh"
```

如果不知道远端路径，先 ssh 进去查：
```bash
ssh awesome-gpu-name "find ~ -name set_claude.sh 2>/dev/null | head -3"
```

## 注意事项

- `git push origin main` 是 **对外可见操作**，确认改动正确再执行
- ssh 部署前确认远端 `git pull` 能拉到最新 main
- 如果远端路径不对，`set_claude.sh` 会报错退出（有 health check）

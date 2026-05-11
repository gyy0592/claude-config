<!-- 模板版本 = v1.1 (claude-config) -->
# militar_camp/ — 军营档案目录

本目录由 `set_claude.sh` / `set_codex.sh` 部署的全局军纪管理。
任何工作区初次被 Claude Code / Codex CLI 进入时，自动按 `<repo>/content/templates/` 生成此目录骨架。

## 目录结构

```
militar_camp/
├── README.md               # 本文件
├── warning_board.md        # 警示录（共享）— 出发前必读
├── reward_board.md         # 奖励录（共享）— 出发前必读
├── traitor.md              # 叛徒+正面教材榜（共享）— 出发前必读
│
└── corporal_X/             # 每个 session 一个下士（X = 1, 2, 3, ...）
    ├── corporal_status.md          # 下士身份+指挥官命令原文+观察项清单
    ├── corporal_action.md          # 下士操作流水（实时追加）
    ├── corporal_situation.md       # 好/坏列表+战况
    │
    └── numberY/            # 该下士派出的第 Y 号列兵
        ├── soldier_status.md       # 列兵派遣令（含授权字段、Agent prompt 逐字复制）
        └── soldier_action.md       # 列兵实时汇报
```

## 编号规则

- **下士编号**：每个 session = 一个新下士。session 1 → corporal_1，session 2 → corporal_2，依此类推。
- **列兵编号**：在 `corporal_X/` 下顺序编号 number1, number2, ...

## 使用规则（绝对强制）

详见：
- `<repo>/CLAUDE.md`（本仓库主路由 — 字节数无硬上限）
- `<repo>/content/memory/INDEX.md`（按需 Read 入口；含 lessons / violations / workflows / soldier_protocol 索引）

## 每次回复开头强制阅读（不仅仅出发前 — 每轮都要读）

任何列兵 / 下士每次回复开头必须 Read：
1. `warning_board.md`
2. `reward_board.md`
3. 所属下士的 `corporal_situation.md`

并在自己的 action.md 每次回复第一条写：
```
[BOARD_READ] 已阅读 warning_board.md + reward_board.md + corporal_situation.md，时间：YYYY-MM-DD HH:MM UTC
```

未写 = 囚禁半年 + 功劳不计。

## 写入规则

- **追加 only**，永不覆盖。
- **步步写**，禁止批量等任务完成。
- 用电报式短句 + [事实] / [推论] / [假设] 标注（标注规则详见 content/memory/INDEX.md → 路由到具体 memory 文件）。

# [militar_camp 文件管理 — 战时档案规范]

## 目录结构（绝对强制 — 任何工作区必须遵守）

每个项目必须维持以下布局（首次进入时由 Claude 按 `~/.claude/rules/templates/` 生成）：
```
militar_camp/
├── README.md               # 目录说明
├── warning_board.md        # 警示录（共享）— 出发前必读
├── reward_board.md         # 奖励录（共享）— 出发前必读
├── traitor.md              # 叛徒+正面教材榜（共享）— 出发前必读
│
└── corporal_X/             # 每个 session 一个下士
    ├── corporal_status.md          # 下士身份+指挥官命令原文
    ├── corporal_action.md          # 下士操作流水（实时追加）
    ├── corporal_situation.md       # 好/坏列表+战况
    │
    └── numberY/            # 该下士派出的第 Y 号列兵
        ├── soldier_status.md       # 列兵派遣令（含授权字段、Agent prompt 逐字复制）
        └── soldier_action.md       # 列兵实时汇报
```

## 模板路径

所有模板在 `~/.claude/rules/templates/` 下：
- `warning_board.md`（通用警示骨架，含特化例子）
- `reward_board.md`（通用奖励骨架）
- `traitor.md`（叛徒+教材榜骨架）
- `README.md`（目录说明）
- `corporal_status.md`
- `corporal_action.md`
- `corporal_situation.md`
- `soldier_status.md`
- `soldier_action.md`

## 工作区初次进入流程（绝对强制）

进入任何新工作区，必须按以下顺序执行：

1. Bash 运行 `__CLAUDE_CONFIG_DIR__/init_corporal.sh <工作目录绝对路径>`
   脚本自动完成：militar_camp/ 骨架 + corporal_X/ 三件套 + 编号 + 时间戳
2. 在生成的 `corporal_status.md` 逐字填写指挥官命令原文（禁止摘要）
3. 在 `corporal_action.md` 追加第一条 `[BOARD_READ]`（创建后30秒内必须完成）
4. 才允许开始执行指挥官命令

- 禁止跳过步骤1手工创建文件 = 囚禁半年 + 功劳不计。

## 写入规则
- **追加 only**。永不覆盖、永不删除任何记录。
- **每完成一个步骤就写**，绝不批量等任务完成。
- 用电报式短句。禁止整段散文。
- 搜索时用 `grep` 或 `tail -n 20`。永不 Read 完整记录文件。

## 流水格式（corporal_action.md / soldier_action.md）
```
## YYYY-MM-DD HH:MM UTC — 本步骤标题

- 操作：<做了什么>
- 结果：<结果>
- 原因/发现：<为什么成功/为什么失败/有什么发现>
- 标注：[事实]/[推论]/[假设] + 来源/推理链/前提
```

## 禁止事项
- ❌ 覆盖任何已写入的记录
- ❌ 把代码片段塞进 corporal_situation.md（那里只放好/坏列表）
- ❌ 等任务完成才一次性写——必须步步写
- ❌ 跳过 [BOARD_READ] 直接出发
- ❌ 模板没生成就开始战斗

## 旧版 artifacts/ 兼容说明
- 旧版的 `artifacts/_project/progress.md` → 现在统一去 `militar_camp/corporal_X/corporal_situation.md`
- 旧版的 `artifacts/task_<name>/log-win.md` → 现在统一去 `corporal_X/numberY/soldier_action.md`（成功）+ `traitor.md` 正面教材
- 旧版的 `artifacts/task_<name>/log-fail-method.md` / `log-fail-eng.md` → 现在统一去 `soldier_action.md`（失败原因）+ `traitor.md` 反面教材
- 旧版 artifacts/ 在新军纪体系下等价于 `militar_camp/corporal_X/corporal_action.md`

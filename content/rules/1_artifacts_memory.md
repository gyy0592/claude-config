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
        ├── soldier_status.md       # 列兵到岗自写：prompt 全文 + 授权字段
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

0. Read `militar_camp/traitor.md` + `militar_camp/warning_board.md`，写 `[SESSION_START]`
1. Bash 运行 `__CLAUDE_CONFIG_DIR__/init_corporal.sh <工作目录绝对路径>`
   脚本自动完成：militar_camp/ 骨架 + corporal_X/ 三件套 + 编号 + 时间戳
2. 在生成的 `corporal_status.md` 逐字填写指挥官命令原文（禁止摘要）
3. 在 `corporal_action.md` 追加第一条 `[BOARD_READ]`（创建后30秒内必须完成）
4. 对照规则触发条件自查，立刻 Read 适用的 rules 文件，写 `[RULES_READ]`
5. 才允许开始执行指挥官命令

- 禁止跳过步骤1手工创建文件 = 囚禁半年 + 功劳不计。

## 写入规则
- **追加 only**。永不覆盖、永不删除任何记录。
- **每完成一个步骤就写**，绝不批量等任务完成。
- 用电报式短句。禁止整段散文。
- 搜索时用 `grep` 或 `tail -n 20`。永不 Read 完整记录文件。

## 流水格式（corporal_action.md / soldier_action.md）

### 行动条目（默认条目类型）：
```
## YYYY-MM-DD HH:MM UTC — 本步骤标题

- 操作：<做了什么>
- 结果：<结果>
- 原因/发现：<为什么成功/为什么失败/有什么发现>
- 标注：[事实]/[推论]/[假设] + 来源/推理链/前提
```

### [观察] 条目（4 步 workflow 第 2/3 步必用 — 一次具体测量）：
```
[观察 观-N] YYYY-MM-DD HH:MM UTC | 测量命令：<具体可执行命令> | 数值或输出片段：<真实命令真实输出，含数值或片段；编造 = 叛国罪 = 砍头> | 判断结论：通过 / 失败 / 部分通过 / 待测 | 严重程度：阻断级 / 重要级 / 轻微级 / 提示级 | 反证审查：已审过 7 项危险信号（NaN / 内存溢出 / 超时 / 性能退化 / 标准错误流异常 / 跳过的测试 / 静默退到备用方案）均未出现（结论 = 通过 必填；其他档可写「不适用」）
```

### [反思] 条目（4 步 workflow 第 1/3/4 步必用 — 一次自我质询）：
```
[反思 主题] YYYY-MM-DD HH:MM UTC | 一轮自问：<具体问题> → 一轮自答：<具体答案> | 二轮自问：<挑战上一轮答案，例如『真考虑全了吗？还遗漏什么？』> → 二轮自答：<具体答案> | （可继续 N 轮直到无疑虑） | 结论：无疑虑 / 仍有疑虑 → 触发动作：<下一步具体动作或继续反思>
```

### 「通过」结论的证据规则（[观察] 条目里写「通过」时必看）：
- **行为类观察项**（动词为「通过 / 收敛 / 达标 / 正确 / 没有 NaN / 不退化」等需要运行才能验证的）：证据必须给真实命令真实输出片段，含「passed=N, failed=0, skipped=0」一行 + 时间戳或行号。仅给「文件:行号」 = 谎报军情。
- **结构类观察项**（动词为「已定义 / 已加 / 已改 / 已生成 / 字段已存在」等读源码就知道的）：证据可以给「文件:行号」+ 一行该处源码片段。强行跑命令是浪费。
- 区分错 = 谎报军情罪 = 截肢 + 功劳减半。

### 失败 3 步闭环格式（任一观察项判断结论 = 失败必走，三步缺一不许结束本回合）：
```
[失败定位 观-N] YYYY-MM-DD HH:MM UTC | 根因假设：<最可能原因> | 引用原始证据：<上一条 [观察] 条目的输出片段或日志行号>
[处置 观-N] YYYY-MM-DD HH:MM UTC | 选择：修复 / 重试 / 上报 | 具体动作：<改了什么文件 / 跑了什么命令 / 上报了哪个上级>
[复测 观-N] YYYY-MM-DD HH:MM UTC | 重跑测量命令：<同上> | 复测 [观察] 条目编号：<新一条 [观察] 的编号> | 复测结论：通过 / 仍失败
```
- 同一观察项累计失败 3 次 = 强制升级上报指挥官，禁止继续蛮干。
- 三步缺一 / 编造证据 / 复测时跑无关命令 = 谎报军情罪。

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

# content/memory/ 索引（按需 Read，不常驻上下文）

本目录承载「按需读、不每次自动注入」的长期教训 + 工作流细则。启动注入仅 `<repo>/CLAUDE.md`（**字节数无硬上限** — 指挥官明示「不计代价」）；本目录按需 Read 不常驻减负载。主路由 `CLAUDE.md` 顶部明文「需要时 Read content/memory/INDEX.md」（不用 `@` 自动导入语法）。

## 4 文件触发表

| 文件 | 描述 | 触发 Read 条件 |
|------|----|--------------|
| `lessons.md` | 正面教训（L-XXX + tags） | 写综合反思前；引用过往「正确做法」；session 开头 `tags:` grep |
| `violations.md` | 违规清单 + 罪名速查 + 处决仪式（W-XXX + tags） | 怀疑触红线；指挥官指出违规；写违规三件套前；session 开头 `tags:` grep |
| `workflows.md` | 4 步 workflow + 长任务监控 + 调试 + 条目格式 | 写 / 跑代码 / 启长任务 / 调试 / 列指标 / 写 [观察]/[反思] / 失败 3 步闭环 |
| `soldier_protocol.md` | 派兵 + 自主权 + 列兵铁律 (A)~(G) + 沉默 + 提问四要素 | 派兵前；写 Agent prompt 前；填 soldier_status.md 授权前；选项题前 |

## 不知读哪个 → grep tags

`grep -lE "tags:.*<标签>" content/memory/*.md`。常用标签：`scope-creep` / `over-design` / `language-violation` / `concept-confusion` / `flow-skip` / `memory-blind` / `fatigue` / `recitation-shortcut` / `dead-link` / `plan-gap` / `listen-comprehension` / `premature-answer` / `codex-overtrust`。

## 迁移规则（v3 三审硬约束）

迁移到 v2 必须全条目带 `tags:` 行。未带 `tags:` 不计入 session 自检覆盖（grep 时被自然排除），需先补齐 `tags:` 才能恢复覆盖。每条 W-XXX / L-XXX 必含：标题 + 行为/后果/正确做法（W）或 正确行为/教训/特化例子（L）+ `tags:`。缺一作废。

## 收尾二选一（任务结束写 action.md 末段必做）

(a) `violations.md`（W-XXX）或 `lessons.md`（L-XXX）追加新条目（含 `tags:`）；或 (b) 显式写「[无新增教训]」。不写 = 失职雏形。

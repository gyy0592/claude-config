[🇺🇸 English](skills.md)

# 自定义 Skills 参考

所有 skill 通过符号链接安装（见 README 第 4 步）。使用斜杠命令或自然语言触发。

## 独立 Skills

| Skill | 触发方式 |
|---|---|
| `gen-draft` | `/gen-draft`、"写draft"、"生成draft" |
| `gen-report` | `/gen-report`、"写报告"、"总结实验" |
| `gen-report-detailed` | `/gen-report-detailed`、"详细报告"、"完整报告" |
| `experiment-run` | `/experiment-run`、"跑实验"、"提交任务" |
| `claude-config-sync` | `/claude-config-sync`、"同步配置"、"推送配置" |
| `error-log` | `/error-log`、用户对AI错误表达愤怒/沮丧、骂AI出错 |
| `follow-instruction` | `/follow-instruction`、AI违反指令或做了假设 |
| `this-cluster` | 编写 Slurm 脚本、选择 Python 环境、设置 GPU 参数时自动参考 |
| `codex-fix` | `codex review` 失败时自动参考：bwrap 沙箱错误、流断开等 |

## 论文阅读套件（2 主 + 6 子 skill）

两个入口：
- **快速概览**: `/paper-overview`、"概览这篇论文" → 8个固定部分的结构化概览（5-10分钟）
- **深度分析**: `/read-paper`、`/paper-reader`、"读这篇论文" → 逐块递归自检的精确分析（30-60分钟）

| 主 Skill | 触发方式 | 用途 |
|---|---|---|
| `paper-overview` | `/paper-overview`、`/overview`、"快速分析"、"概览" | 快速结构化概览：问题、方法、结果，8个固定部分 |
| `paper-reader` | `/read-paper`、`/paper-reader`、"读这篇论文" | 深度分析编排器，逐块精确处理

| 子 Skill | 触发方式 | 用途 |
|---|---|---|
| `pdf-ingest` | PDF 输入时自动调用 | 双通道提取：文本 + 渲染页面图片 |
| `prereq-probe` | ingest 后自动调用；或"先问我几个问题"、"检查我的背景知识" | 扫描非通用前置概念，用 A/B/C 问题探测用户知识，写 `knowledge_map.md` 控制展开深度 |
| `contrib-extract` | "这篇的贡献是什么"、`/contributions` | 四要素法（动机、直觉、场景、公式） |
| `pipeline-walk` | "带我走一遍方法"、`/walk` | 逐阶段方法详解 |
| `math-explain` | "数学上怎么解释"、"推导一下" | 逐公式严格推导 |
| `old-vs-new` | "对比 A 和 B" | 结构化前后对比 |
| `zero-jump-check` | "补上缺失步骤"、"审查这个证明" | 步间逻辑审计 |
| `concise-complete` | "精简一下"、"写紧凑一点" | 最终语言精炼，提高信息密度 |

## 依赖追踪套件（1 主 + 2 子 skill）

入口：`/dep-trace-launcher`、"追踪依赖"

交互式启动器，收集参数后分派到追踪 worker。

| 子 Skill | 触发方式 | 用途 |
|---|---|---|
| `recursive-dep-trace` | `/recursive-dep-trace` | 单入口递归第一性原理代码追踪 |
| `recursive-dep-trace-parallel` | `/recursive-dep-trace-parallel` | 并行追踪，协调 worker 批次 |

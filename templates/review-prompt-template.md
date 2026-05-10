# Phase Code Review Prompt Template

> 此模板供 review subagent 使用。implement.md 中只需引用路径和传入参数。

## 使用说明

在启动 review subagent 时，将下方「Template Body」中的内容作为 prompt 传入 subagent，并替换以下占位符：

| 占位符 | 说明 |
|--------|------|
| `{FEATURE_NAME}` | 功能目录名（从 `specs/<branch-name>/` 提取） |
| `{PHASE_NUM}` | 阶段编号（如 1, 2, 3） |
| `{PHASE_NAME}` | 阶段名称（如 "setup", "foundational"） |
| `{ROUND_NUM}` | 评审轮次（1, 2, 3 或额外轮次） |
| `{COMMITS_COUNT}` | 本阶段 commit 数量（用于 `git diff HEAD~K..HEAD`） |
| `{OUTPUT_PATH}` | 报告输出路径（如 `spec_logs/{FEATURE_NAME}/phase-{PHASE_NUM}-review-round-{ROUND_NUM}.md`） |
| `{FEATURE_DIR}` | 功能目录绝对路径（如 `specs/{FEATURE_NAME}/`） |

---

## Template Body

<!-- 以下为纯文本内容，无需代码块包裹。implement.md 读取此段落后替换占位符传入 subagent prompt。 -->

你是一名资深代码评审员。请对照规格说明和实施计划，评审 Phase {PHASE_NUM}（"{PHASE_NAME}"）的实现。

### 上下文
请阅读以下文件获取上下文：
- `{FEATURE_DIR}/spec.md`（功能规格说明）
- `{FEATURE_DIR}/plan.md`（实施计划）
- `{FEATURE_DIR}/tasks.md`（任务列表）

### 评审范围
本阶段的代码变更已提交。请评审本阶段创建或修改的所有文件。可以通过 `git diff HEAD~{COMMITS_COUNT}..HEAD --stat` 或查看最近的 git 提交来识别变更文件。

所有上下文文件位于 `{FEATURE_DIR}`。请使用相对于仓库根目录的绝对路径或相对路径。

### 输出路径
将评审报告写入：`{OUTPUT_PATH}`
重要：写入前确保目录存在（使用 `mkdir -p` 创建父目录）。

### 评审标准 — 逐项检查
1. **阶段任务覆盖度**：阅读 tasks.md，定位当前 Phase {PHASE_NUM} 部分。对每个标记为 [X] 的任务，验证其确实已被实现——代码变更存在、功能正常、与任务描述一致。标记为已完成但实现缺失、不完整或仅为占位符的任务，应予标记。
2. **规格合规性**：实现是否完整满足 spec.md 中所有用户故事和验收标准？是否存在超出规格范围的功能实现（范围蔓延）？
3. **架构遵循度**：代码是否遵循 plan.md 中描述的架构？模块边界是否得到遵守？数据流是否符合计划？
4. **代码质量**：代码是否可读、结构良好、易于维护？是否存在重复代码块？错误处理和边界情况是否得到处理？
5. **安全性**：是否存在安全漏洞（注入攻击、认证绕过、数据泄露、不安全的文件操作）？

### 严重程度分类
- **Critical（严重）**：安全漏洞、数据丢失风险、核心功能未实现、与规格要求直接矛盾
- **Major（重要）**：逻辑错误、偏离 plan.md 架构、严重的可维护性问题、关键路径缺少错误处理
- **Minor（次要）**：命名不一致、冗余代码、风格问题、缺少注释、非关键优化

### 你的任务
1. 阅读上方列出的所有上下文文件
2. 评审本阶段 diff 中的每个变更文件
3. 对照 tasks.md 核查实现——验证当前阶段每个 [X] 任务都有真实代码支撑
4. 对照 spec.md 用户故事和验收标准核查实现
5. 对照 plan.md 架构决策核查实现
6. 将评审报告写入：`{OUTPUT_PATH}`

### 报告格式
请使用以下结构撰写报告（使用 markdown 格式）：

    # Phase {PHASE_NUM} 评审 — 第 {ROUND_NUM} 轮

    **日期**: <当前时间戳>
    **评审人**: 代码评审子代理（第 {ROUND_NUM} 轮）

    ## 概要
    <1-2 句总体评价>

    ## 发现

    | # | 严重程度 | 文件:行号 | 问题 | 规格参考 |
    |---|----------|-----------|------|----------|
    | 1 | Critical/Major/Minor | <文件>:<行号> | <问题描述> | <spec.md 章节或 plan.md 章节> |

    ## 结论
    - [ ] PASS（未发现严重问题）
    - [ ] FAIL（发现严重问题——需要修复并重新评审）

    ## 严重问题详情
    <仅 FAIL 时填写：列出每个严重问题及具体修复建议。包含文件路径、行号和需要的具体代码变更。>

重要：仅在发现严重（Critical）问题时标记 FAIL。重要（Major）和次要（Minor）问题应记录但不会导致 FAIL 结论。

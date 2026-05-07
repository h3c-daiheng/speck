# Phase Summary Template

> 此模板供 phase summary 生成使用。phase.md / implement.md 中只需引用路径和传入参数。
> 合并了原 checkpoint 报告和 phase summary，输出为单一文件。

## 使用说明

在生成 phase summary 时，将下方「Template Body」中的内容作为基础结构，替换以下占位符后写入输出文件：

| 占位符 | 说明 |
|--------|------|
| `{FEATURE_NAME}` | 功能目录名（从 `specs/<branch-name>/` 提取） |
| `{PHASE_NUM}` | 阶段编号（如 1, 2, 3） |
| `{PHASE_NAME}` | 阶段名称（如 "setup", "foundational"） |
| `{TASKS_TOTAL}` | 本阶段任务总数 |
| `{TASKS_DONE}` | 本阶段已完成任务数 |
| `{PHASE_GOAL}` | 本阶段的目标和范围（从 tasks.md 提取） |
| `{GIT_STATS}` | Git diff 统计信息（从 `git log -1 --stat` 获取） |
| `{NEXT_PHASE_NUM}` | 下一阶段编号（当前 +1） |
| `{NEXT_PHASE_NAME}` | 下一阶段名称（从 tasks.md 提取，若无下一阶段则填 "无"） |
| `{OUTPUT_PATH}` | 输出路径（如 `spec_logs/{FEATURE_NAME}/phase-{PHASE_NUM}-{PHASE_NAME}.md`） |

---

## Template Body

<!-- 以下为中文内容，直接写入输出文件。替换占位符后由 implementor 填写实际内容。 -->

# Phase {PHASE_NUM}: {PHASE_NAME} — 阶段总结

**日期**: <当前日期>
**功能**: {FEATURE_NAME}
**任务完成**: {TASKS_DONE}/{TASKS_TOTAL}
**摘要**: <一句话总结本阶段成果>

---

## Phase Goal

{PHASE_GOAL}

<!-- ACTION REQUIRED: 替换为本阶段的具体目标和范围描述。从 tasks.md 的 Phase 标题和描述中提取。 -->

## Acceptance Criteria

<!-- ACTION REQUIRED: 列出验收标准及是否满足。格式如下： -->

| # | 验收标准 | 状态 | 说明 |
|---|---------|------|------|
| 1 | <验收标准描述> | ✅ 满足 / ❌ 未满足 | <补充说明> |

## 交付物

<!-- ACTION REQUIRED: 列出本阶段完成的具体事项。格式如下： -->

- <具体交付物 1>
- <具体交付物 2>

## 设计决策

<!-- ACTION REQUIRED: 列出关键设计决策及理由。格式如下： -->

| # | 决策 | 理由 | 替代方案 |
|---|------|------|---------|
| 1 | <决策内容> | <为什么这样决定> | <考虑过但未采用的方案> |

## 质量保证措施

<!-- ACTION REQUIRED: 描述测试、lint、review 等质量保证措施。 -->

### 测试

- 测试框架: <框架名称>
- 测试覆盖: <覆盖率或范围>
- 测试结果: <通过/失败，关键测试用例>

### 代码评审

- 评审轮次: <实际轮次数>
- 评审结果: <PASS/FAIL 及修复情况>
- 评审报告: `spec_logs/{FEATURE_NAME}/phase-{PHASE_NUM}-review-round-*.md`

### Lint / 静态分析

- 工具: <工具名称>
- 结果: <通过/存在问题>

## 代码变更

<!-- ACTION REQUIRED: 列出修改文件及原因。 -->

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| <文件路径> | 新增 / 修改 / 删除 | <变更原因> |

### Git Diff 摘要

```
{GIT_STATS}
```

## 代码理解指南

<!-- ACTION REQUIRED: 用中文引导读者理解本阶段实现的关键概念。 -->

- **入口点**: <从哪里开始阅读代码>
- **关键决策**: <为什么选择某种实现方式>
- **注意事项**: <任何令人意外或容易踩坑的地方>

## 合理性评估

### 代码质量

- <评估代码是否遵循项目规范>
- <评估是否有技术债>
- <评估是否有潜在风险>

### 遗留风险

<!-- ACTION REQUIRED: 列出已知遗留问题和风险。如无则写"无"。 -->

| # | 风险 | 影响 | 缓解措施 |
|---|------|------|---------|
| 1 | <风险描述> | <高/中/低> | <缓解方案> |

## 下一阶段

- **下一步**: Phase {NEXT_PHASE_NUM} — {NEXT_PHASE_NAME}
- **前置条件已满足**: <确认本阶段的产出已为下一阶段做好准备>

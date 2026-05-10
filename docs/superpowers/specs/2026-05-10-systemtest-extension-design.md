# System Test Extension 设计文档

**日期**: 2026-05-10
**状态**: Draft

## 概述

为 speckit 新增 `systemtest` 扩展，提供 3 个手动触发的命令，用于系统级端到端测试的完整流程：生成测试用例 → 生成测试脚本 → 执行测试脚本。

## 目标

- 基于功能设计文档自动生成系统测试用例
- 基于测试用例自动生成可执行的测试脚本代码
- 执行测试脚本并输出详细的测试过程和结果报告
- 支持用户通过注入上下文和参考材料定制测试策略

## Extension 身份

| 字段 | 值 |
|------|-----|
| ID | `systemtest` |
| Name | System Test |
| Version | `1.0.0` |
| Description | 系统测试扩展：生成测试用例、测试脚本，执行并报告结果 |

## 文件结构

### Extension 目录

```
extensions/systemtest/
├── extension.yml
├── commands/
│   ├── generate-test-cases.md
│   ├── generate-test-scripts.md
│   └── run-test-scripts.md
├── scripts/
│   └── bash/
│       └── detect-test-framework.sh
├── config-template.yml
└── README.md
```

### 用户项目侧产出

```
spec_test/{feature}/
├── context.md              # 用户注入：测试倾向说明
├── references/             # 用户注入：参考材料
│   ├── *.md                # 历史测试用例文档
│   └── *.py / *.js / ...   # 可参考的测试脚本
├── test-cases.md           # 命令1 产出：测试用例文档
├── scripts/                # 命令2 产出：可执行测试代码
│   ├── test_*.py / *.test.js / ...
│   └── ...
└── reports/                # 命令3 产出：测试结果报告
    └── report-{timestamp}.md
```

**用户注入说明**：

- `context.md`：测试倾向说明，如"重点关注错误处理和边界值"、"需要覆盖并发场景"等
- `references/`：可包含历史测试用例文档（`.md`）和参考测试脚本代码，用于指导用例风格和脚本实现

## 命令设计

### 命令 1: generate-test-cases

**命令全称**: `speckit.systemtest.generate-test-cases`

**输入来源**：

1. `specs/{feature}/` 下的所有可用设计文档（spec.md, plan.md, data-model.md, contracts/, quickstart.md 等）
2. `spec_test/{feature}/context.md` — 用户测试倾向说明
3. `spec_test/{feature}/references/*.md` — 历史测试用例文档，用于参考用例编写风格和覆盖维度

**处理逻辑**：

1. 调用 `check-prerequisites.sh --json` 获取 FEATURE_DIR 和可用文档
2. 读取 `specs/{feature}/` 下的所有设计文档
3. 从 spec.md 提取用户故事和验收标准
4. 从 contracts/ 提取接口定义和预期行为
5. 从 quickstart.md 提取验证场景
6. 从 data-model.md 提取数据约束和边界条件
7. 读取 `spec_test/{feature}/context.md`（如存在），获取测试倾向
8. 读取 `spec_test/{feature}/references/*.md`（如存在），参考历史用例风格
9. 生成测试用例，覆盖：正常流程、边界条件、异常处理、数据约束

**输出**: `spec_test/{feature}/test-cases.md`

**输出格式**：

```markdown
# 系统测试用例 — {feature}

## TC-001: 用户注册成功场景
- **优先级**: P1
- **来源**: US1 (spec.md)
- **前置条件**: 数据库已初始化
- **测试步骤**:
  1. 发送 POST /api/users，body: {name: "test", email: "test@example.com"}
  2. 验证响应状态码 201
  3. 验证响应 body 包含 user id
- **预期结果**: 用户创建成功，返回完整用户对象

## TC-002: 用户注册 - 邮箱已存在
...
```

### 命令 2: generate-test-scripts

**命令全称**: `speckit.systemtest.generate-test-scripts`

**输入来源**：

1. `spec_test/{feature}/test-cases.md` — 命令 1 的产出
2. `spec_test/{feature}/references/` 中的代码文件 — 参考脚本风格、框架、工具函数
3. `specs/{feature}/plan.md` — 技术栈信息

**框架检测优先级**：

1. `spec_test/{feature}/references/` 中的参考脚本 → 沿用其框架和风格
2. 项目已有的测试文件和依赖配置（pytest、Jest、Go testing 等）
3. 从 plan.md 技术栈推断默认框架
4. 运行 `detect-test-framework.sh` 自动检测

**输出**: `spec_test/{feature}/scripts/` 目录下的可执行测试代码

**关键约束**：

- 每个测试函数标注对应的 `TC-XXX` 用例 ID，便于追溯
- 文件命名跟随项目现有测试文件命名风格
- 如果 references/ 中有参考脚本，沿用其辅助函数和工具模式

### 命令 3: run-test-scripts

**命令全称**: `speckit.systemtest.run-test-scripts`

**输入来源**：

1. `spec_test/{feature}/scripts/` — 测试脚本目录

**处理逻辑**：

1. 扫描 `scripts/` 目录下所有测试文件
2. 根据文件类型确定执行命令（pytest、jest、go test 等）
3. 执行测试，实时捕获 stdout/stderr
4. 收集测试结果（通过/失败/错误/跳过）
5. 生成详细报告

**输出**: `spec_test/{feature}/reports/report-{timestamp}.md`

**报告内容**（必须包含）：

1. **测试执行概要**：总用例数、通过数、失败数、跳过数、总耗时、结论
2. **测试过程日志**：完整的 stdout/stderr 输出
3. **逐用例结果明细**：每个 TC-XXX 的执行状态、耗时、失败原因
4. **失败用例详情**：完整的错误堆栈和断言信息
5. **整体结论**：PASS / FAIL

**报告格式**：

```markdown
# 系统测试报告 — {feature}
生成时间: 2026-05-10 14:30:00

## 执行概要
| 指标 | 值 |
|------|-----|
| 总用例 | 12 |
| 通过 | 10 |
| 失败 | 2 |
| 跳过 | 0 |
| 耗时 | 3.2s |
| 结论 | **FAIL** |

## 测试过程

### 执行命令
```
pytest spec_test/my-feature/scripts/ -v
```

### 标准输出
```
......F..F..
```

## 逐用例结果
| 用例 ID | 描述 | 状态 | 耗时 |
|---------|------|------|------|
| TC-001 | 用户注册成功 | PASS | 0.3s |
| TC-007 | 邮箱格式无效 | FAIL | 0.1s |

## 失败详情

### TC-007: 邮箱格式无效
```
AssertionError: Expected 400, got 200
  at test_user_validation.py:45
```
```

## Hook 集成

**不绑定任何工作流 hook**。3 个命令完全由用户手动调用，用户自行决定何时开始系统测试流程。

## 用户侧配置

用户在项目根目录的 `.specify/extensions.yml` 中启用：

```yaml
extensions:
  systemtest:
    enabled: true
    config:
      # 可选：指定测试框架（auto = 自动检测）
      test_framework: auto
      # 可选：测试超时时间（秒）
      timeout: 300
```

## 数据流

```
specs/{feature}/                    spec_test/{feature}/
┌─────────────────┐                ┌──────────────────┐
│ spec.md         │                │ context.md       │ ← 用户注入
│ plan.md         │                │ references/      │ ← 用户注入
│ data-model.md   │                └────────┬─────────┘
│ contracts/      │                         │
│ quickstart.md   │                         ▼
└────────┬────────┘              generate-test-cases
         │                                │
         └────────────┬───────────────────┘
                      ▼
              test-cases.md ──────────────┐
                                           │
                                           ▼
                                  generate-test-scripts
                                           │
                                           ▼
                                   scripts/ (测试代码)
                                           │
                                           ▼
                                    run-test-scripts
                                           │
                                           ▼
                                  reports/report-*.md
```

## 约束

- 测试用例生成仅针对系统级端到端测试，不生成单元测试
- 框架检测优先使用用户提供的参考材料，其次自动检测
- 测试脚本必须标注 TC-XXX 用例 ID，保持与用例文档的追溯关系
- 执行测试时必须完整输出测试过程（stdout/stderr）和结果，不能只输出摘要

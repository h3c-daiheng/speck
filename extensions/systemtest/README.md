# System Test Extension

系统测试扩展：基于功能设计文档自动生成系统测试用例和可执行脚本，并执行测试输出详细报告。

## 命令

| 命令 | 说明 |
|------|------|
| `speckit.systemtest.generate-test-cases` | 基于 specs/{feature}/ 设计文档生成测试用例 |
| `speckit.systemtest.generate-test-scripts` | 基于测试用例生成可执行测试代码 |
| `speckit.systemtest.run-test-scripts` | 执行测试脚本并输出详细报告 |

## 工作流

```text
specs/{feature}/          spec_test/{feature}/
设计文档                    用户上下文 + 参考材料
      │                          │
      └──────────┬───────────────┘
                 ▼
     generate-test-cases
                 │
                 ▼
         test-cases.md
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

## 用户注入

在 `spec_test/{feature}/` 下提供上下文和参考材料：

- `context.md` — 测试倾向说明（如"重点关注错误处理"）
- `references/*.md` — 历史测试用例文档（影响用例风格）
- `references/*.py/*.js/...` — 参考测试脚本（影响框架选择和代码风格）

## 配置

在 `.specify/extensions/systemtest/systemtest-config.yml` 中配置：

```yaml
test_framework: auto  # auto | pytest | jest | go-test | vitest | mocha
timeout: 300
```

## 框架检测

当 `test_framework: auto` 时，按以下优先级检测：

1. `spec_test/{feature}/references/` 中的参考脚本
2. 项目已有的测试文件和依赖配置
3. plan.md 中的技术栈信息

## 安装

```bash
specify extension add systemtest
```

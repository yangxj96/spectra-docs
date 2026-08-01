---
name: graphify
description: 使用 graphify 构建、更新和查询代码库的架构知识图谱。涉及模块关系、社区结构、高层依赖、god nodes、路径分析或 graphify-out/ 既有图谱时使用；源码级定义和调用链优先使用 CodeGraph。
---

# Spectra 架构图谱

graphify 用于架构级分析，输出 `graphify-out/` 下的图谱、HTML 可视化、JSON 数据和审计报告。它补充 CodeGraph：graphify 关注模块和社区，CodeGraph 关注符号、调用链和影响范围。

## 选择操作

- 用户询问模块关系、社区结构或高层依赖：优先检查 `graphify-out/graph.json`，存在时直接执行 `graphify query`。
- 用户要求重新构建：执行 `graphify .`；指定路径时使用 `graphify <path>`。
- 用户要求增量更新：执行 `graphify update .`。
- 用户要求路径或概念解释：分别执行 `graphify path "<from>" "<to>"` 或 `graphify explain "<concept>"`。
- 用户要求查询已有图谱：执行 `graphify query "<question>"`，必要时追加 `--dfs` 或 `--budget <tokens>`。

## 工作规则

1. 默认路径为当前项目根目录，不要为普通架构问题重复构建已有图谱。
2. 运行命令前确认 `graphify` 可用；不可用时报告安装/环境问题，不要索要 API key。
3. 只把 `graphify-out/GRAPH_REPORT.md` 的 God Nodes、Surprising Connections 和 Suggested Questions 摘要给用户，不要粘贴完整报告。
4. 修改代码后，按需执行 `graphify update .`；CodeGraph 索引仍是源码级查询的首选。
5. 不要把 `graphify-out/` 生成物加入 Git；根 `.gitignore` 已忽略该目录。

## 常用命令

```bash
graphify .                         # 构建当前项目图谱
graphify update .                  # 增量更新
graphify query "问题"              # 查询已有图谱
graphify path "概念A" "概念B"      # 最短路径
graphify explain "概念"            # 解释节点
graphify . --no-viz                # 构建但跳过可视化
graphify . --mode deep             # 更深入的关系抽取
```

如果 `graphify-out/graph.json` 不存在，先运行完整构建，再执行查询。架构问题不要用 grep 代替图谱查询；涉及具体函数定义、调用链或 blast radius 时切换到 CodeGraph MCP/CLI。

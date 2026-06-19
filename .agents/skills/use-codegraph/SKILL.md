---
name: use-codegraph
description: Guidelines on using CodeGraph to optimize codebase exploration.
---

# CodeGraph Skill

Use this skill when you need to research Swift code architecture, resolve symbol dependencies, or analyze the impact of changes.

## Best Practices

1. **Initialization**: Build the semantic graph database by executing `npx @colbymchenry/codegraph init` at the root of the workspace.
2. **Querying**: Query the database using Tree-sitter powered semantic queries instead of broad grep searches.
3. **Symbol Navigation**: Use CodeGraph to trace function calls, subclassing relationships, and protocol implementations in the Swift code.

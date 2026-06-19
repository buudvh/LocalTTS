# Workspace Rules & Workflows

## Rules

- **Use CodeGraph for Codebase Navigation**: When exploring this project's Swift code, symbol relationships, call graphs, or conducting impact analysis, you MUST use `codegraph` (initialized via `npx @colbymchenry/codegraph init` or the CodeGraph MCP server). Avoid excessive file reads or generic grep searches to save tokens and improve accuracy.
- **Swift Guidelines**: Follow standard Swift API Design Guidelines and project structure.
- **Thorough Syntax & API Verification**: Since you are developing on a platform (Windows) different from the build target (iOS/macOS), you MUST check all Swift API signatures and syntax extremely carefully. Double-check Apple's official documentation for methods like `Data.write(to:options:)` (not `atomically`), `AVAudioPlayer` initialization, and file handles before making changes to prevent build failures on the CI server.

## Workflows

You can trigger the following workflows:
- `/use-codegraph`: Build and initialize the CodeGraph semantic database.

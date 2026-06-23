# Workspace Rules & Workflows

## Rules

- **Use CodeGraph for Every Request**: For every new user request and during codebase exploration, you MUST automatically use CodeGraph to analyze symbol relationships, call graphs, and change impact before reading files or performing generic grep searches. On Windows, execute CLI commands via `cmd /c "codegraph <args>"` to bypass PowerShell script execution policy blocks. Use `codegraph explore` (or the `codegraph_explore` MCP tool) as the primary entry point for exploration and trust its output to avoid redundant file reads or search tool calls.
- **Swift Guidelines**: Follow standard Swift API Design Guidelines and project structure.
- **Thorough Syntax & API Verification**: Since you are developing on a platform (Windows) different from the build target (iOS/macOS), you MUST check all Swift API signatures and syntax extremely carefully. Double-check Apple's official documentation for methods like `Data.write(to:options:)` (not `atomically`), `AVAudioPlayer` initialization, and file handles before making changes to prevent build failures on the CI server.
- **Automatic Double-Check Logic**: After making any source code modifications, you MUST automatically follow the instructions in the `double-check-logic` skill to perform impact analysis, verify with sub-agents, test integration, and check Xcode project references/CI compatibility before declaring the task complete.

## Workflows

You can trigger the following workflows:
- `/use-codegraph`: Build and initialize the CodeGraph semantic database.

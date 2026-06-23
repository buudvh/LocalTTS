---
name: use-codegraph
description: Guidelines on using CodeGraph to optimize codebase exploration.
---

# CodeGraph Skill

Use this skill when you need to research codebase structure, trace function calls, resolve symbol dependencies, or analyze the impact/blast-radius of changes.

## Core Concepts

CodeGraph builds a local-first semantic knowledge graph using Tree-sitter parsers and stores it in SQLite (`.codegraph/codegraph.db`). 
Using CodeGraph tools allows the agent to get surgical, verbatim source code, call flows, and impact analysis in a single tool call, bypassing slow grep/read crawls.

## Command & Tool Usage Guidelines

### 1. Windows Execution Environment
Because Windows PowerShell restricts executing script wrappers (like `npx.ps1` or global npm wrappers) under default execution policies, you **MUST** run all CodeGraph CLI commands via `cmd.exe`:
- **Correct**: `cmd /c "codegraph explore <query>"`
- **Incorrect**: `codegraph explore <query>` or `npx @colbymchenry/codegraph explore <query>` (these will fail with execution policy security errors).

### 2. Primary Entry Points
- **MCP Tool**: If the MCP server is registered in the toolset, use `codegraph_explore` for almost all structural questions.
- **CLI Command**: Otherwise, use `cmd /c "codegraph explore \"<query>\""` to search symbols, view caller/callee trees, and analyze impact in one go.

### 3. Command Reference

| Task | Command | Description |
|---|---|---|
| **Initialize / Build** | `cmd /c "codegraph init"` | Creates `.codegraph/` and indexes the codebase. Run once per project. |
| **Check Status** | `cmd /c "codegraph status"` | Shows indexed files, node/edge counts, database size, and sync status. |
| **Explore Flow / Query** | `cmd /c "codegraph explore \"<query>\""` | Returns relevant symbols' source code, call paths, and change impact. |
| **View Symbol / File** | `cmd /c "codegraph node <symbol_or_file>"` | Retrieves a symbol's implementation and callers, or prints a file with line numbers. |
| **Call Hierarchy** | `cmd /c "codegraph callers <symbol>"`<br>`cmd /c "codegraph callees <symbol>"` | Traces functions/methods that call or are called by a target symbol. |
| **Blast Radius** | `cmd /c "codegraph impact <symbol>"` | Traces dependencies transitively to analyze the blast radius of a change. |
| **Test Impact** | `cmd /c "codegraph affected <files>"` | Finds test files affected by changed source files (great for verification). |
| **Manual Sync** | `cmd /c "codegraph sync"` | Manually triggers incremental index update (though auto-sync watches files). |

## Codebase Exploration Workflow

1. **Start with CodeGraph**: For any new task or inquiry, run `cmd /c "codegraph explore \"<keyword_or_symbol>\""` first. Avoid generic grep search or directory lists.
2. **Trust the Source**: Treat the verbatim source code returned by CodeGraph as read. Do not perform redundant `view_file` calls for files/methods already retrieved.
3. **Handle Staleness Warnings**:
   - During the 2-second debounce window after file edits, CodeGraph returns a `⚠️` staleness banner indicating that some files have changed.
   - If a symbol or file is marked as stale in the banner, read the live file content directly using `view_file` or check with git diff.
4. **No Re-verification**: Do not waste tokens or calls run-verifying CodeGraph queries with manual grep. Trust the graph's static resolution.

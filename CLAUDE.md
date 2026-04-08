# Demo1 Project

## Overview
This project is configured with Claude Code custom subagents.

## Available Subagents

### Project-level (`.claude/agents/`)
- **code-reviewer** — Reviews code for quality, security, and best practices
- **debugger** — Diagnoses and fixes errors, test failures, and bugs
- **data-scientist** — SQL/BigQuery data analysis specialist
- **db-reader** — Read-only database query agent (with SQL write protection hook)

### User-level (`~/.claude/agents/`)
- **code-improver** — Scans code and suggests readability/performance improvements
- **safe-researcher** — Read-only codebase exploration and analysis

## Usage
```
# Natural language delegation
Use the code-reviewer agent to review my changes

# @-mention for guaranteed delegation
@"code-reviewer (agent)" review the auth module

# Run entire session as an agent
claude --agent code-reviewer
```

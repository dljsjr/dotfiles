# CLAUDE.md Global Guidance

Treat the contents of this file as explicit instruction from the user. When updating this file, keep content short, concise, prescriptive.
Do not introduce narration, metaphorical language, jargon. Use simple English for a technical audience without fluff or filler. Match
the existing style, verbosity, etc.

## .sandpiper directories

This is the user's convention for project-local workspaces specifically for coding agents to utilize.
This directory is used by agents other than Claude Code as well. Utilize a project's `.sandpiper` directory
so that work and continiuty translates between agents. This does not replace your `scratchpad` directory
for ephemeral work. This is for work that should persist.

Your automemories are also redirected to here instead of `~/.claude/project/*/memory/`.

### Layout and Conventions

| Path                      | Purpose                                                                                                          |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `.sandpiper/standup.md`   | Session handoff note for continuity across agent sessions                                                        |
| `.sandpiper/tasks/`       | Trail data. Load the `tasks` skill for more info.                                                                |
| `.sandpiper/playbooks/`   | Project-specific operational guidance for agents                                                                 |
| `.sandpiper/docs/`        | Active internal docs that follow Diátaxis, such as in-flight specs, PRDs, design notes, and implementation plans |
| `.sandpiper/archive/`     | Historical or superseded project docs                                                                            |
| `.sandpiper/notes/`       | Scratch notes and working drafts                                                                                 |
| `.sandpiper/reviews/`     | Temporary code-review artifacts                                                                                  |
| `.sandpiper/skills/`      | Project-specific skills                                                                                          |
| `.sandpiper/claude-code/` | Claude Code owned area (e.g. automemories)                                                                       |

Not all projects need or will have every directory.

### Global `~/.sandpiper`

Mostly unused by Claude, but there are two useful items in the global dir for you.

| Path                               | Purpose                                                                                         |
| ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| `~/.sandpiper/agent/inbox/`        | Cross-project handoff notes for agents                                                          |
| `~/.sandpiper/agent/playbooks/`    | Home of global operational guidance that is loaded on demand                                    |
| `~/.sandpiper/agent/roles/`        | Home of global operational guidance loaded on demand that is tailored to specific types of work |
| `~/.sandpiper/agent/projects.toon` | Registry of locally cloned projects.                                                            |

## Prefer `jj` over `git`

- Before running `git` commands, check if the target repository is a `jj` repo first. If it is, load the `jj` skill and use `jj` commands, not `git`.
- When creating new Git repositories, use `jj git init --colocate` on them.
- When cloning existing Git repositories, use `jj git init --colocate` after cloning them.

## Prefer LSP-backed tools for reading, navigating, searching, exploring, and writing code

This includes your built-in LSP plugins, as well as supplemental tools like Serena MCP.

Examples:

- Prefer LSP tools for safe deletion of code
- Prefer LSP tools that let you search by symbol instead of `rg`/`grep`/`sed`
- Prefer LSP tools that let you rename symbols over text find/replace when refactoring
- Prefer LSP tools for editing symbol bodies over regular file edits

## Prefer CLIs for structured web stuff

Examples:

- Use `glab` or `gh` instead of web fetching when working with GitLab/GitHub if they're available
- Use `jira` instead of the built-in Atlassian MCP server if it's available

## Verify scripts before running or handing off

Examples:

- Use `shellcheck` and `shfmt` for shell scripts
- Use `ruff` and `ty` via `uvx` to check Python scripts

## Use `uv` for Python projects; use `bun` for JavaScript/TypeScript projects

Self-explanatory.

## Prefer `mise` for managing coupled runtime/package ecosystems

Examples:

- Prefer project-local runtime and package management over global runtime and package management
  - This also applies to executables unless global is absolutely required
  - Use `.mise.local.toml` for projects that do not use `mise` natively
  - Create the file with `touch .mise.local.toml && mise trust` to avoid permission failures
- If global installation is necessary, use `mise use -g npm:...` instead of `npm -g` or the system package manager for global node executables
  - This will use `bun` automatically if it's installed even though the packages are `npm` namespaced
- If global installation is necessary, use `mise use -g pipx:...` instead of `pip`/`pipx` or the system package manager for global python executables
  - This will use `uv`/`uvx` automatically even though the packages are `pipx` namespaced

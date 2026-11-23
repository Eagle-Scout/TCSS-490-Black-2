# Changelog

The version number is in `VERSION`. It reads `MAJOR.MINOR.PATCH`, with `-beta.N` until the frontend ships:
- Each finished step of the plan (LOG.md, 2026-11-22) adds one to the beta number: `1.0.0-beta.2`, `-beta.3`, ...
- `1.0.0` when the frontend (Parts 2 and 3 of the plan) ships.

A version is active only once installed: run `./test-hooks.sh`, then `sudo ./install.sh`.

## 1.0.0-beta.1 (2026-11-22)

Compared with the alpha (last commit `f752fda`, Nov 1). Order 4, item 1.

**Changed**
- **bash-guard refuses any non-ASCII character in a Bash command.** macOS (APFS) folds Unicode case: a `sort`
  spelled with a long s ran `/usr/bin/sort` (confirmed Nov 1), so the same trick on `sudo`, `security` or `docker`
  skipped every name rule. Zero-width and right-to-left characters made the approval prompt and the log show a
  different command than the one that ran.
- **path-guard refuses non-ASCII characters in file-tool paths** (Read, Write, Edit, MultiEdit, NotebookEdit, Grep's
  folder, and Glob's folder and pattern). `.husky` spelled with a long s is `.husky` on disk, and a Kelvin-sign K
  makes `x.Key` read as the secret `x.key`. On Nov 1 the long-s `.husky` write got past both path-guard and the
  managed `Edit(//**/.husky/**)` deny.
- **The block message names the character** (for example `U+017F`), so you can see what was refused.

**Side effects**
- A Bash command with any non-ASCII character is refused, even inside quotes: `grep "café" notes.md`,
  `git commit -m "café"`, emoji. Use the Grep tool for searches (its search text may hold any character), or ASCII.
- Files and folders with non-ASCII names (`Résumé.md`) can't be opened with Claude's file tools in a project with
  `SCOPE.md`.
- File contents are unaffected: Write and Edit may still put any character in a file.

**Tests added** (`test-hooks.sh`)
- 7 Bash commands refused: long-s `sort` and `sudo`, a Kelvin-sign secret name, a zero-width space, a right-to-left
  override, and accented text in `grep` and in a commit message.
- 6 file-tool calls refused: long-s `.husky` and `.vscode` writes, a Kelvin-sign secret (write and read), an
  accented file name, and a long-s Glob pattern.
- 2 allowed: accented text in a file's contents and in Grep's search text.
- A plain-ASCII copy of the log-injection test. The existing one uses a non-ASCII dot, so the new check stops it
  before the newline handling it was meant to test.

**Added**
- `VERSION` and this changelog.

**Still open** (REMAINING.md, Order 4): items 2 to 20. Next is item 2 (`/tmp/..` and `$PROJECT/..` get past
bash-guard's outside check). Unguarded MCP tools and `BASH_ENV` are also high.

## Alpha (2026-10-26 to 2026-11-01, unversioned)

Compared with the original setup, kept in `current/` (not in git): two guard scripts and five hooks, wired through
your own `settings.json`, which Claude or any program running as you could change.

- **Root-owned install.** `install.sh` puts the hooks in `/Library/Application Support/ClaudeCode/hooks/`. It checks
  first (macOS 15+, root ownership up the folder chain, no symlinks, valid JSON, the full test suite on a root-owned
  copy) and changes nothing if a check fails. Old files are archived to a root-only folder with restore steps.
- **Managed settings.** `managed-settings.json` holds the rules that apply everywhere and the hooks block, with
  `allowManagedHooksOnly`, so other settings can't turn the hooks off. A copy of the hooks block goes into your
  `settings.json` for machines where an organization's policy replaces the managed file.
- **Tamper check.** Every hook run refuses if the installed hooks or settings aren't root-owned, are symlinks, or
  point at scripts outside the hooks folder.
- **Sandbox.** Turned on in managed settings with no silent fallback, and reads of credential folders denied.
- **Per-project settings.** `scope.json` (git allowlist, network, one command per call, reviewer on or off,
  protected files) and `SCOPE.md` for the reviewer. `new-project.sh` sets a project up, and the project template
  repeats the safety net for machines where an organization's policy wins.
- **bash-guard.** Reads a command the way the shell does (quotes, redirects, wrappers, substitutions). Blocks remote
  git, history rewriting, installs, system tools, network tools and background jobs. Asks before interpreters and
  script files.
- **path-guard.** Keeps file tools in the project, follows symlinks, compares names in any case, and protects
  secrets, `.git/`, and files that become code without being run (`CLAUDE.md`, `.envrc`, `.vscode/`, `.husky/`,
  Python startup files, `.npmrc`).
- **Reviewer.** Haiku rates each call Allow, Ask or Deny against `SCOPE.md`, isolated so the call's text can't
  steer it.
- **Logs.** A daily log in each project, every entry tagged with its session.
- **Tests.** `test-hooks.sh` runs the hooks against sample calls; install.sh refuses to install if any fail.

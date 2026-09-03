---
name: code-review
description: Review priorities for zsh-theme-nick pull requests — what deserves real scrutiny versus what to skip. Use for every PR review.
---

# Review priorities

Single-purpose repo: one zsh prompt theme (`nick.zsh-theme` + `lib/async-git.zsh`), no build step, no other language. The two files below are the entire product.

## Spend real attention here

- **Fork/state invariants in `lib/async-git.zsh`.** One background probe per prompt is the whole point of this file — a synchronous `git status` blocking every keystroke is the exact failure it exists to prevent. Flag: `async_start_worker` invoked more than once per session (must stay behind the `_nick_git_worker_started` guard), any added `_nick_git_probe` call outside `prompt_git`'s existing warm/cold-cache branch, or `NICK_GIT_STATUS_READY` set or read out of step with `_nick_git_preexec`'s invalidation. Code like this can look correct and still silently reintroduce per-keystroke blocking.
- **WezTerm-gated escapes (`_uc_start`/`_uc_end`).** Every styled underline checks `$TERM == wezterm` and stays wrapped in `%{...%}`. A new escape sequence added to a segment without that same gate and wrapping either prints raw bytes on other terminals or breaks zsh's prompt-width math.
- **`_nick_git_fields`'s hand-rolled porcelain parsing.** Branch/upstream regex, XY status-code cases, the unborn-branch → `init` rename. A new status code or output shape needs a matching case here, not just wherever `prompt_git` consumes it.
- **`.nvmrc` prefix matching in `prompt_node` is intentional, not a bug** — an `.nvmrc` of `18` must keep satisfying `v18.19.0`. Don't wave through a "fix" toward exact-match.

## Do not spend attention here

- `README.md`, `LICENSE` — prose, no logic.
- `chore(ci): sync caller templates from seankoji-com/.github` PRs touching `.github/workflows/*.yml` — generated from the org's `.github` repo; fix upstream, not here.
- Anything `spec/nick_spec.sh` already pins (porcelain-parsing cases, WezTerm gating, the warm-cache-must-not-fork-git case, palette selection) — a regression fails CI directly; don't restate a shellspec failure as a review comment.
- A green CodeQL check on its own — its `language: actions` matrix (see the comment in `.github/workflows/codeql.yml`) only scans `.github/workflows/*.yml`; there is no shell analyser, so it says nothing about `nick.zsh-theme` or `lib/async-git.zsh`.

## Comment style

- One comment per real issue, not one per file it repeats in.
- Skip restating what shellspec or CodeQL already catch in CI.

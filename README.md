# nick

A Powerline-style zsh theme derived from
[agnoster](https://gist.github.com/3712874), with a git segment that never
blocks the prompt.

Segments, left to right: exit status and job count, `user@host` when it is not
the usual you, git, node version, directory.

## Install

Clone into oh-my-zsh's themes directory and point `ZSH_THEME` at the file
inside it. This is the same layout powerlevel10k uses.

```sh
git clone https://github.com/seankoji-com/zsh-theme-nick \
  ~/.oh-my-zsh_custom/themes/zsh-theme-nick
```

```zsh
ZSH_THEME="zsh-theme-nick/nick"
```

Needs a Nerd Font for the segment separators and glyphs.

## The git segment

`git status` in a prompt is fine until you open a large repo on a network
filesystem, at which point every prompt waits on it. The probe runs in a
background worker and the prompt reads a cache.

One probe, one fork. Branch, upstream divergence, file states and stash
presence all come from a single background job, because asking git separately
for each means three forks per prompt, which is most of what the worker was
meant to avoid.

Indicators:

| Glyph | Meaning |
|---|---|
| `◉` | Staged changes |
| `✱` | Modified files |
| `?` | Untracked files |
| `$` | A stash exists |
| `↑n` `↓n` | Commits ahead of, behind upstream |

The segment is mint when clean, amber when dirty. A stash on its own does not
count as dirty.

Under WezTerm, unmerged conflicts get a red curly underline on the branch name.
That state is easy to lose among the other glyphs.

### Async provider

Registration needs `async_start_worker` and `async_job`. oh-my-zsh vendors a
copy in `lib/git.zsh`, and [mafredri/zsh-async](https://github.com/mafredri/zsh-async)
also works. With neither, the prompt still works and just probes
synchronously.

If you use oh-my-zsh, its own async git prompt is on by default and feeds
`git_prompt_info`, which this theme never calls. Turn it off so you are not
paying for a result nothing reads:

```zsh
zstyle ':omz:alpha:lib:git' async-prompt no
```

## Configuration

| Variable | Effect |
|---|---|
| `DEFAULT_USER` | Hides the `user@host` segment for this username |
| `NICK_WORKTREE_MARKER` | Path fragment marking a worktree checkout, default `/.claude/worktrees/`. Set to `''` to disable |

Inside a worktree the directory segment gets a dotted underline, so it is
obvious which checkout a shell is sitting in. WezTerm only.

The node segment shows only inside a Node project. If `.nvmrc` disagrees with
the running node, the version gets a dashed underline. Prefix match, so an
`.nvmrc` of `18` is satisfied by `v18.19.0`.

## Terminal support

Styled and coloured underlines are a WezTerm SGR extension. Everywhere else
they are suppressed rather than printed as raw escape bytes, so the theme
degrades to plain text.

## Licence

MIT

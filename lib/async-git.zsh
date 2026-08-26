# async-git — feed the prompt a git status without blocking on it.
#
# A synchronous `git status` in a prompt is fine until you open a large repo on
# a network filesystem, at which point every keystroke-to-prompt round trip
# waits on it. This runs the probe in a background worker and caches the result
# for the prompt to read.
#
# Exposes:
#   $NICK_GIT_STATUS        raw output of the probe, empty outside a repo
#   $NICK_GIT_STATUS_READY  1 once the worker has answered at least once
#
# The READY flag matters. Without it, an empty cache is ambiguous: it means
# either "not a git repository" or "the worker has not replied yet", and the
# prompt has to guess. Guessing wrong either drops the git segment on the first
# prompt in a repo, or forks a synchronous probe on every prompt outside one.
#
# Requires an async provider supplying async_start_worker / async_job. Both
# oh-my-zsh (lib/git.zsh vendors one) and mafredri/zsh-async work. Without
# either, the prompt falls back to probing synchronously.

autoload -Uz add-zsh-hook

typeset -g NICK_GIT_STATUS=''
typeset -g NICK_GIT_STATUS_READY=0
typeset -g _nick_git_worker_started=0

# One probe, one fork. The prompt needs branch, upstream divergence, file
# states and whether a stash exists; asking git separately for each means three
# forks per prompt, which is most of what the async worker was meant to avoid.
# Stash presence is emitted as a header line so it rides along with the rest.
_nick_git_probe() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local stash=0
  command git rev-parse --verify --quiet refs/stash >/dev/null 2>&1 && stash=1
  print -r -- "#stash:$stash"
  command git status --porcelain -b 2>/dev/null
}

# True when an async provider is loadable.
_nick_async_available() {
  (( $+functions[async_start_worker] )) && return 0
  autoload -Uz async 2>/dev/null && (( $+functions[async_start_worker] ))
}

_nick_git_callback() {
  # $3 is the job's stdout.
  NICK_GIT_STATUS="$3"
  NICK_GIT_STATUS_READY=1
  # Repaint now that the answer has arrived, but only if the line editor is
  # actually up. Calling reset-prompt outside ZLE is an error.
  zle && zle reset-prompt
}

_nick_git_precmd() {
  # Start the worker once, not on every prompt. async_start_worker forks, so
  # calling it per precmd spawns a process per prompt to replace a process per
  # prompt, which is not an improvement.
  if (( ! _nick_git_worker_started )); then
    async_start_worker nick_git -u -n || return
    async_register_callback nick_git _nick_git_callback
    _nick_git_worker_started=1
  fi
  # The worker keeps its own cwd, so point it at the current directory before
  # each job.
  async_worker_eval nick_git builtin cd -q "$PWD"
  async_job nick_git _nick_git_probe
}

# Invalidate before a command runs. Otherwise the prompt drawn immediately
# after `git commit` shows the pre-commit state until the worker catches up.
_nick_git_preexec() {
  NICK_GIT_STATUS=''
  NICK_GIT_STATUS_READY=0
}

nick_async_git_register() {
  _nick_async_available || return 1
  add-zsh-hook precmd _nick_git_precmd
  add-zsh-hook preexec _nick_git_preexec
  return 0
}

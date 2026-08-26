# vim:ft=zsh ts=2 sw=2 sts=2
#
# nick — a Powerline-style zsh theme, derived from agnoster.
# https://gist.github.com/3712874

0=${(%):-%N}
NICK_THEME_DIR=${0:A:h}

source "$NICK_THEME_DIR/lib/async-git.zsh"

CURRENT_BG='NONE'
SEGMENT_SEPARATOR='\ue0b0'

# Undercurl helpers. Styled and coloured underlines are a WezTerm SGR
# extension, so they are guarded on $TERM: elsewhere they would print the raw
# escape bytes. Wrapped in %{...%} like the %K/%F codes below so zsh counts
# them as zero-width when measuring the prompt.
# $2 style: 1 single, 2 double, 3 curly (default), 4 dotted, 5 dashed.
_uc_start() {
  [[ "$TERM" == wezterm ]] || return 0
  printf '%%{\033[4:%dm\033[58:5:%dm%%}' "${2:-3}" "$1"
}
_uc_end() {
  [[ "$TERM" == wezterm ]] || return 0
  printf '%%{\033[4:0m\033[59m%%}'
}

# Begin a segment. Takes background and foreground colours.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_end() {
  if [[ -n $CURRENT_BG && $CURRENT_BG != 'NONE' ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

# user@hostname, shown only when it is not the usual you, or over SSH.
prompt_context() {
  local user="${USER:-$(id -un)}"
  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment "#4c1d95" "#f0abfc" "%(!.%{%F{yellow}%}.)$user@%m"
  fi
}

# Reduce probe output to four lines: branch, indicator glyphs, dirty, conflict.
# Split out from prompt_git so the parsing can be tested without a repository
# and without the prompt escape soup around it.
_nick_git_fields() {
  local probe=$1
  local -a lines
  lines=("${(@f)probe}")
  (( ${#lines} )) && [[ -n "$lines[1]" ]] || return 1

  local has_stash=0
  if [[ "$lines[1]" == '#stash:'* ]]; then
    has_stash=${lines[1]#\#stash:}
    shift lines
  fi
  (( ${#lines} )) || return 1

  local branch_info="${lines[1]##'## '}"
  local branch="${branch_info%%...*}"
  [[ "$branch" == 'Initial commit on '* || "$branch" == 'No commits yet on '* ]] && branch=init

  local untracked=0 modified=0 staged=0 conflict=0 line
  for line in "${lines[@]:1}"; do
    [[ -z "$line" ]] && continue
    case $line in
      '??'*) untracked=1 ;;
      (DD|AU|UD|UA|DU|AA|UU)*) conflict=1 ;;
    esac
    [[ "$line" == ?[MD]* ]] && modified=1
    [[ "$line" == [MADRCU]* && "$line" != '??'* ]] && staged=1
  done

  local ahead='' behind=''
  [[ "$branch_info" =~ 'ahead ([0-9]+)' ]] && ahead="${match[1]}"
  [[ "$branch_info" =~ 'behind ([0-9]+)' ]] && behind="${match[1]}"

  local details=''
  (( staged ))    && details+='◉'
  (( modified ))  && details+='✱'
  (( untracked )) && details+='?'
  (( has_stash )) && details+='$'
  [[ -n "$ahead" ]]  && details+=" ↑${ahead}"
  [[ -n "$behind" ]] && details+=" ↓${behind}"

  print -r -- "$branch"
  print -r -- "$details"
  print -r -- "$(( staged || modified || untracked ))"
  print -r -- "$conflict"
}

prompt_git() {
  local probe
  if (( NICK_GIT_STATUS_READY )); then
    probe=$NICK_GIT_STATUS
  else
    # First prompt of a session, or async unavailable. Pay for one probe.
    probe=$(_nick_git_probe)
  fi
  [[ -n "$probe" ]] || return 0

  local -a f
  f=("${(@f)$(_nick_git_fields "$probe")}") || return 0
  (( ${#f} >= 4 )) || return 0

  local branch=$f[1] details=$f[2] dirty=$f[3] conflict=$f[4]

  local bg_color fg_color
  if (( dirty )); then
    bg_color='#facc15'   # amber
    fg_color='#0f172a'
  else
    bg_color='#4ade80'   # mint
    fg_color='#0f172a'
  fi

  # A red curly underline on the branch name flags unmerged conflicts, which
  # are otherwise easy to lose among the status glyphs.
  local branch_display=$branch
  (( conflict )) && branch_display="$(_uc_start 196)${branch}$(_uc_end)"

  local display=" ${branch_display}"
  [[ -n "$details" ]] && display+=" ${details}"

  prompt_segment "$bg_color" "$fg_color" "%B${display}%b"
}

# Node version, shown only inside a Node project.
prompt_node() {
  [[ -f package.json || -d node_modules ]] || return 0
  (( $+commands[node] )) || return 0
  local node_version=$(node -v 2>/dev/null)
  [[ -n "$node_version" ]] || return 0

  local text="⬡ ${node_version}"
  # Dashed underline when the running node does not match .nvmrc. Prefix match,
  # so an .nvmrc of "18" is satisfied by v18.19.0.
  if [[ -f .nvmrc ]]; then
    local wanted="$(<.nvmrc)"
    wanted="${wanted#v}"
    local actual="${node_version#v}"
    if [[ -n "$wanted" && "$actual" != "$wanted"* ]]; then
      text="$(_uc_start 208 5)${text}$(_uc_end)"
    fi
  fi
  prompt_segment 237 226 "$text"
}

# Directory, truncated to the last three components.
prompt_dir() {
  local expanded_path="${(%):-%~}"
  local parts=("${(s:/:)expanded_path}")

  local text
  if [[ ${#parts} -gt 3 ]]; then
    if [[ "$expanded_path" == "~"* ]]; then
      text="~/${parts[-3]}/${parts[-2]}/${parts[-1]}"
    else
      text="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
    fi
  else
    text="%~"
  fi

  # Dotted underline inside a git worktree checkout, so it is obvious which
  # checkout a shell is sitting in.
  if [[ -n "$NICK_WORKTREE_MARKER" && "$PWD" == *"$NICK_WORKTREE_MARKER"* ]]; then
    text="$(_uc_start 44 4)${text}$(_uc_end)"
  fi

  prompt_segment 237 253 "$text"
}

# Exit status, root shell, background jobs.
prompt_status() {
  local symbols=""
  (( RETVAL != 0 ))     && symbols+="%{%F{203}%}✘ "
  (( UID == 0 ))        && symbols+="%{%F{220}%}⚡ "
  (( ${#jobstates} ))   && symbols+="%{%F{81}%}⚙ "
  [[ -n "$symbols" ]]   && prompt_segment 235 default "${symbols% }"
  return 0
}

build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_context
  prompt_git
  prompt_node
  prompt_dir
  prompt_end
}

# Path fragment that marks a worktree checkout. Set to '' to disable the
# dotted-underline directory hint.
: ${NICK_WORKTREE_MARKER='/.claude/worktrees/'}

RPROMPT=''
PROMPT='%{%f%b%k%}$(build_prompt)
» '

# Registration is best-effort: without an async provider the prompt still
# works, it just probes synchronously. The `|| true` keeps the theme file from
# reporting failure to whatever sourced it.
if [[ -o interactive ]]; then
  nick_async_git_register || true
fi

# shellcheck shell=bash disable=all
# The theme is zsh-only (prompt escapes, ${(@f)} splitting, $+commands), so
# this suite runs under shellspec's zsh mode rather than bats.
Describe 'nick.zsh-theme'
  Include ./nick.zsh-theme

  Describe '_nick_git_fields'
    # Field order: branch, indicator glyphs, dirty flag, conflict flag.
    probe() { print -r -- "${1}"; }

    It 'returns failure on empty input'
      When call _nick_git_fields ''
      The status should be failure
    End

    It 'reads a clean branch with no indicators'
      When call _nick_git_fields "$(print -l '#stash:0' '## main...origin/main')"
      The line 1 of output should equal 'main'
      The line 2 of output should equal ''
      The line 3 of output should equal '0'
      The line 4 of output should equal '0'
    End

    It 'reads a branch with no upstream'
      When call _nick_git_fields "$(print -l '#stash:0' '## solo')"
      The line 1 of output should equal 'solo'
    End

    It 'renames an unborn branch to init'
      When call _nick_git_fields "$(print -l '#stash:0' '## No commits yet on main')"
      The line 1 of output should equal 'init'
    End

    It 'works without the stash header'
      When call _nick_git_fields '## main...origin/main'
      The line 1 of output should equal 'main'
    End

    Describe 'file states'
      It 'flags untracked files'
        When call _nick_git_fields "$(print -l '#stash:0' '## main' '?? new.txt')"
        The line 2 of output should equal '?'
        The line 3 of output should equal '1'
      End

      It 'flags modified files'
        When call _nick_git_fields "$(print -l '#stash:0' '## main' ' M edited.txt')"
        The line 2 of output should equal '✱'
        The line 3 of output should equal '1'
      End

      It 'flags staged files'
        When call _nick_git_fields "$(print -l '#stash:0' '## main' 'M  staged.txt')"
        The line 2 of output should equal '◉'
        The line 3 of output should equal '1'
      End

      It 'flags a stash'
        When call _nick_git_fields "$(print -l '#stash:1' '## main')"
        The line 2 of output should equal '$'
        # A stash on its own does not make the tree dirty.
        The line 3 of output should equal '0'
      End

      It 'flags an unmerged conflict'
        When call _nick_git_fields "$(print -l '#stash:0' '## main' 'UU both.txt')"
        The line 4 of output should equal '1'
      End

      It 'combines staged, modified and untracked in a stable order'
        When call _nick_git_fields "$(print -l '#stash:1' '## main' 'M  a' ' M b' '?? c')"
        The line 2 of output should equal '◉✱?$'
      End
    End

    Describe 'upstream divergence'
      It 'reads ahead'
        When call _nick_git_fields "$(print -l '#stash:0' '## main...origin/main [ahead 3]')"
        The line 2 of output should equal ' ↑3'
      End

      It 'reads behind'
        When call _nick_git_fields "$(print -l '#stash:0' '## main...origin/main [behind 2]')"
        The line 2 of output should equal ' ↓2'
      End

      It 'reads both at once'
        When call _nick_git_fields "$(print -l '#stash:0' '## main...origin/main [ahead 3, behind 2]')"
        The line 2 of output should equal ' ↑3 ↓2'
      End
    End
  End

  Describe '_uc_start / _uc_end'
    # Styled underlines are a WezTerm SGR extension. Other terminals would
    # print the raw escape bytes into the prompt.
    It 'emits nothing outside WezTerm'
      run_it() { TERM=xterm-256color _uc_start 196; }
      When call run_it
      The output should equal ''
      The status should be success
    End

    It 'emits an SGR sequence under WezTerm'
      run_it() { TERM=wezterm _uc_start 196; }
      When call run_it
      The output should include '58:5:196'
    End

    It 'defaults to the curly style'
      run_it() { TERM=wezterm _uc_start 196; }
      When call run_it
      The output should include '[4:3m'
    End

    It 'honours an explicit style'
      run_it() { TERM=wezterm _uc_start 208 5; }
      When call run_it
      The output should include '[4:5m'
    End
  End

  Describe 'prompt_git'
    It 'renders nothing when the probe is empty and ready'
      run_it() {
        NICK_GIT_STATUS_READY=1
        NICK_GIT_STATUS=''
        prompt_git
      }
      When call run_it
      The output should equal ''
      # Nothing to render is not an error. A prompt segment returning non-zero
      # leaks into $? for anything downstream that reads it.
      The status should be success
    End

    # A warm cache must not fork git at all. That is the entire point of the
    # async worker; probing anyway would undo it.
    It 'does not invoke git when the cache is ready'
      run_it() {
        NICK_GIT_STATUS_READY=1
        NICK_GIT_STATUS="$(print -l '#stash:0' '## main')"
        _nick_git_probe() { print -u2 'PROBED'; }
        prompt_git >/dev/null
      }
      When call run_it
      The stderr should equal ''
    End

    It 'probes synchronously when the cache is not ready'
      run_it() {
        NICK_GIT_STATUS_READY=0
        _nick_git_probe() { print -l '#stash:0' '## fallback'; }
        prompt_git
      }
      When call run_it
      The output should include 'fallback'
    End

    It 'uses the amber palette for a dirty tree'
      run_it() {
        NICK_GIT_STATUS_READY=1
        NICK_GIT_STATUS="$(print -l '#stash:0' '## main' '?? x')"
        prompt_git
      }
      When call run_it
      The output should include '#facc15'
    End

    It 'uses the mint palette for a clean tree'
      run_it() {
        NICK_GIT_STATUS_READY=1
        NICK_GIT_STATUS="$(print -l '#stash:0' '## main')"
        prompt_git
      }
      When call run_it
      The output should include '#4ade80'
    End
  End

  Describe 'prompt_dir'
    It 'marks a worktree checkout when the marker matches'
      run_it() {
        TERM=wezterm
        NICK_WORKTREE_MARKER='/.claude/worktrees/'
        PWD='/home/u/repo/.claude/worktrees/feat'
        prompt_dir
      }
      When call run_it
      The output should include '58:5:44'
    End

    It 'leaves an ordinary directory unmarked'
      run_it() {
        TERM=wezterm
        NICK_WORKTREE_MARKER='/.claude/worktrees/'
        PWD='/home/u/repo/src'
        prompt_dir
      }
      When call run_it
      The output should not include '58:5:44'
    End

    It 'can have the marker disabled'
      run_it() {
        TERM=wezterm
        NICK_WORKTREE_MARKER=''
        PWD='/home/u/repo/.claude/worktrees/feat'
        prompt_dir
      }
      When call run_it
      The output should not include '58:5:44'
    End
  End

  Describe 'sourcing the theme'
    # Registration is best-effort, and a theme file that reports failure to
    # whatever sourced it aborts oh-my-zsh's theme loading.
    It 'reports success even with no async provider available'
      run_it() {
        unset -f async_start_worker 2>/dev/null
        source ./nick.zsh-theme
      }
      When call run_it
      The status should be success
      The stderr should equal ''
    End
  End
End

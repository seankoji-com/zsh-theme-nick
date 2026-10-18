# shellcheck shell=bash disable=all
Describe 'async Git worker recovery'
  Include ./lib/async-git.zsh

  setup_provider() {
    typeset -g starts=0 stops=0 registrations=0 jobs=0 evals=0 alive=0
    typeset -g start_fails=0 job_loses_worker=0
    typeset -g silent_failure_step='' silent_failure_code=7
    typeset -gA registered_callbacks=()
    async_start_worker() {
      (( starts++ ))
      (( start_fails )) && return 1
      alive=1
      silent_failure_step=''
      return 0
    }
    async_register_callback() {
      registered_callbacks[$1]=$2
      (( registrations++ ))
      return 0
    }
    async_stop_worker() {
      (( stops++ ))
      alive=0
      # Stopping an already missing worker can fail after cleaning its state.
      return 1
    }
    async_worker_eval() {
      (( evals++ ))
      [[ "$silent_failure_step" == eval ]] && return "$silent_failure_code"
      if (( ! alive )); then
        _nick_git_callback '[async]' 3 '' 0 'missing worker' 0
        return 1
      fi
      return 0
    }
    async_job() {
      [[ "$silent_failure_step" == job ]] && return "$silent_failure_code"
      if (( job_loses_worker )); then
        alive=0
        _nick_git_callback '[async]' 3 '' 0 'missing worker' 0
        return 1
      fi
      (( alive )) || { print -u2 'submitted to stopped worker'; return 1; }
      (( jobs++ ))
      return 0
    }
  }

  Describe 'fatal provider callbacks'
    Parameters
      3
      130
    End
    It 'stops a lost worker and restarts it only at the next prompt'
      run_it() {
        setup_provider
        _nick_git_precmd
        NICK_GIT_STATUS='stale'
        NICK_GIT_STATUS_READY=1
        alive=0
        _nick_git_callback '[async]' "$1" '' 0 'worker lost' 0
        print -r -- "callback:$starts:$stops:$_nick_git_worker_started:[$NICK_GIT_STATUS]:$NICK_GIT_STATUS_READY"
        _nick_git_precmd
        _nick_git_precmd
        print -r -- "recovered:$starts:$registrations:$jobs:$evals:$alive"
      }
      When call run_it "$1"
      The line 1 of output should equal 'callback:1:1:0:[]:0'
      The line 2 of output should equal 'recovered:2:2:3:3:1'
      The stderr should equal ''
      The status should be success
    End

  End

  Describe 'other provider errors'
    Parameters
      1
      2
    End
    It 'preserves healthy-worker reuse and cache on other provider errors'
      run_it() {
        setup_provider
        _nick_git_precmd
        NICK_GIT_STATUS='cached'
        NICK_GIT_STATUS_READY=1
        _nick_git_callback '[async]' "$1" '' 0 'nonfatal message' 0
        _nick_git_precmd
        print -r -- "$starts:$stops:$registrations:$jobs:$NICK_GIT_STATUS:$NICK_GIT_STATUS_READY"
      }
      When call run_it "$1"
      The output should equal '1:0:1:2:cached:1'
      The status should be success
    End

  End

  It 'does not submit another job after worker_eval reports a missing worker'
    run_it() {
      setup_provider
      _nick_git_precmd
      alive=0
      _nick_git_precmd
      local failed=$?
      print -r -- "failed:$failed:$jobs:$_nick_git_worker_started:$stops"
      _nick_git_precmd
      print -r -- "recovered:$starts:$registrations:$jobs:$alive"
    }
    When call run_it
    The line 1 of output should equal 'failed:1:1:0:1'
    The line 2 of output should equal 'recovered:2:2:2:1'
    The stderr should equal ''
    The status should be success
  End

  It 'recovers next prompt when the worker disappears at job submission'
    run_it() {
      setup_provider
      _nick_git_precmd
      job_loses_worker=1
      _nick_git_precmd
      local failed=$?
      job_loses_worker=0
      print -r -- "failed:$failed:$jobs:$_nick_git_worker_started:$stops"
      _nick_git_precmd
      print -r -- "recovered:$starts:$registrations:$jobs:$alive"
    }
    When call run_it
    The line 1 of output should equal 'failed:1:1:0:1'
    The line 2 of output should equal 'recovered:2:2:2:1'
    The stderr should equal ''
    The status should be success
  End

  It 'retries a failed restart on the following prompt'
    run_it() {
      setup_provider
      _nick_git_precmd
      alive=0
      _nick_git_callback '[async]' 130 '' 0 'crashed worker' 0
      start_fails=1
      _nick_git_precmd
      local failed=$?
      print -r -- "failed:$failed:$starts:$_nick_git_worker_started:$jobs:$registrations"
      start_fails=0
      _nick_git_precmd
      print -r -- "recovered:$starts:$registrations:$jobs:$alive"
    }
    When call run_it
    The line 1 of output should equal 'failed:1:2:0:1:1'
    The line 2 of output should equal 'recovered:3:2:2:1'
    The stderr should equal ''
    The status should be success
  End

  Describe 'submission failures without callbacks'
    Parameters
      eval 7
      job 9
    End
    It 'invalidates a warm cache and retries after a transport failure'
      run_it() {
        setup_provider
        _nick_git_precmd
        NICK_GIT_STATUS='stale'
        NICK_GIT_STATUS_READY=1
        silent_failure_step=$1
        silent_failure_code=$2
        _nick_git_precmd
        local failed=$?
        print -r -- "failed:$failed:$stops:$_nick_git_worker_started:[$NICK_GIT_STATUS]:$NICK_GIT_STATUS_READY"
        _nick_git_precmd
        print -r -- "recovered:$starts:$registrations:$jobs:$alive"
      }
      When call run_it "$1" "$2"
      The line 1 of output should equal "failed:$2:1:0:[]:0"
      The line 2 of output should equal 'recovered:2:2:2:1'
      The stderr should equal ''
      The status should be success
    End
  End

  Describe 'job name routing'
    Parameters
      '[async/eval]' 3
      '[async/eval]' 130
      unrelated_job 3
      unrelated_job 130
    End
    It 'does not treat other job names as worker loss at fatal status values'
      run_it() {
        setup_provider
        _nick_git_precmd
        NICK_GIT_STATUS='cached'
        NICK_GIT_STATUS_READY=1
        _nick_git_callback "$1" "$2" '' 0 'job failed' 0
        print -r -- "$stops:$_nick_git_worker_started:$NICK_GIT_STATUS:$NICK_GIT_STATUS_READY"
      }
      When call run_it "$1" "$2"
      The output should equal '0:1:cached:1'
      The status should be success
    End
  End

  Describe 'worker callback routing'
    Parameters
      3
      130
    End
    It 'routes only nick_git worker loss to the registered Nick callback'
      run_it() {
        setup_provider
        _nick_git_precmd
        local other_messages=0
        other_callback() { (( other_messages++ )); return 0; }
        async_register_callback other_worker other_callback
        # The provider selects a callback by worker before passing job/status.
        ${registered_callbacks[other_worker]} '[async]' "$1" '' 0 '' 0
        print -r -- "other:$other_messages:$stops:$_nick_git_worker_started"
        ${registered_callbacks[nick_git]} '[async]' "$1" '' 0 '' 0
        print -r -- "nick:$other_messages:$stops:$_nick_git_worker_started"
      }
      When call run_it "$1"
      The line 1 of output should equal 'other:1:0:1'
      The line 2 of output should equal 'nick:1:1:0'
      The stderr should equal ''
      The status should be success
    End
  End
End

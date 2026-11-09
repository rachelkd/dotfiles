# Reports the directory (OSC 7) and each prompt (OSC 133) to Rex, and marks a
# command that ran 10s or more as done or error (OSC 7501) so its tab is flagged.
# Ctrl+C (exit 130) isn't marked.

_rex_preexec() {
  _rex_cmd=$1
  _rex_start=$SECONDS
}

_rex_precmd() {
  local code=$?
  if [[ -n $_rex_start ]] && (( SECONDS - _rex_start >= 10 && code != 130 )); then
    local state=done
    (( code )) && state=error
    local msg=$(print -rn -- "${${_rex_cmd//[[:cntrl:]]/ }[1,200]}" | base64)
    printf '\e]7501;state=%s:app=zsh:msg=%s\e\\' $state $msg
  fi
  unset _rex_start
  printf '\e]7;file://%s%s\a\e]133;A\a' $HOST $PWD
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _rex_preexec
add-zsh-hook precmd _rex_precmd

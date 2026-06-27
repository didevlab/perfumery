# === retro-theme: alias + autocomplete ===
alias rt='retro-theme'

# make sure the completion system is loaded
autoload -Uz compinit 2>/dev/null && compinit -C 2>/dev/null

_retro_theme() {
  local -a themes opts fx
  if (( CURRENT == 2 )); then
    opts=('fx:set screen effect' '-l:list bundled themes' '--all:apply to every terminal' '--detect:show detected terminal')
    _describe -t cmds 'command' opts
    # bundled theme names (slug + display name)
    themes=(${(f)"$(retro-theme -l 2>/dev/null | sed -E 's/ *\[[^]]*\]$//; s/ +$//')"})
    _describe -t themes 'theme' themes
  elif (( CURRENT == 3 )) && [[ ${words[2]} == fx ]]; then
    fx=('crt:retro CRT (Ghostty/Windows Terminal)' 'glow:neon bloom (Ghostty)' 'off:no effect')
    _describe -t fx 'effect' fx
  elif (( CURRENT == 3 )); then
    _describe -t scope 'scope' '(--all)'
  fi
}
compdef _retro_theme retro-theme rt
# === end retro-theme ===

# === retro-theme: alias + autocomplete ===
alias rt='retro-theme'

# make sure the completion system is loaded
autoload -Uz compinit 2>/dev/null && compinit -C 2>/dev/null

_retro_theme() {
  local -a themes opts fx
  if (( CURRENT == 2 )); then
    opts=('fx:toggle screen effect' '-l:list all themes')
    _describe -t cmds 'command' opts
    themes=(${(f)"$(ghostty +list-themes 2>/dev/null | sed -E 's/ \(resources\)//')"})
    _describe -t themes 'theme' themes
  elif (( CURRENT == 3 )) && [[ ${words[2]} == fx ]]; then
    fx=('crt:retro CRT (curvature+scanlines)' 'glow:futuristic (neon bloom)' 'off:no effect')
    _describe -t fx 'effect' fx
  fi
}
compdef _retro_theme retro-theme rt
# === end retro-theme ===

echo "\033[1;34mLade .zshrc...\033[0m"
if $DEBUG_ZSHRC; then
  echo "Starte Debugging für .zshrc"
fi
debug_echo() {
  [[ $DEBUG_ZSHRC == true ]] && echo "\033[1;33m[DEBUG]\033[0m $1"
}

# Debug-Funktion
debug_command() {
  local debug_log="$HOME/.zsh_debug.log"
  echo "Ausführung von Befehl: $*" | tee -a "$debug_log"
  eval "$@" 2>&1 | tee -a "$debug_log"
  local exit_code=$?
  echo "Befehl beendet mit Exit-Code: $exit_code" | tee -a "$debug_log"
  return $exit_code
}

# # Lade zsh-autosuggestions
# load_plugin "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" # Lade zsh-autosuggestions plugin
# echo "Rückgabewert für zsh-autosuggestions.plugin: $?"
# load_plugin $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh # Lade zsh-autosuggestions
# echo "Rückgabewert für zsh-autosuggestions: $?"

# #zsh-syntax-highlighting
# load_plugin $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh # Lade zsh-syntax-highlighting plugin
# echo "Rückgabewert für zsh-syntax-highlighting.plugin: $?"
# load_plugin "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" # Lade zsh-syntax-highlighting
# echo "Rückgabewert für zsh-syntax-highlighting: $?"

# load_plugin "/Users/marco/.config/zsh/aliases.zsh"
# echo "Rückgabewert für aliases: $?"
# load_plugin "/Users/marco/.config/zsh/completions.zsh"
# echo "Rückgabewert für completions: $?"


--cycle --layout=reverse --border --height=90% --preview-window=wrap --marker="*"

# FZF_COLORS="bg+:-1,\
# fg:gray,\
# fg+:white,\
# border:black,\
# spinner:0,\
# hl:yellow,\
# header:blue,\
# info:green,\
# pointer:red,\
# marker:blue,\
# prompt:gray,\
# hl+:red"

# export FZF_DEFAULT_OPTS="--height 60% \
# --border sharp \
# --layout reverse \
# --color '$FZF_COLORS' \
# --prompt '∷ ' \
# --pointer ▶ \
# --marker ⇒"
# export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -n 10'"
# export FZF_COMPLETION_DIR_COMMANDS="cd pushd rmdir tree ls"

# export FZF_TMUX_OPTS="-p"
${red}: for red color
${green}: for green color
${blue}: for blue color
${cyan}: for cyan color
${magenta}: for magenta color
${white}: for white color
You can also use color codes in the format \e[<code>m, where <code> represents the color code. For example:

\e[31m: for red color
\e[32m: for green color
\e[34m: for blue color
\e[36m: for cyan color
\e[35m: for magenta color
\e[37m: for white color
|                                 |
|        (\(\                      |
|       (-.-)o                     |
|       /_(")(")                   |
|_________________________________|
\e[34m:"

    (\____/)
     / @__@ \
    (  (oo)  )
     `-.~~.-'
      /    \
    @/      \_
   (/ /    \ \)
    WW`----'WW




echo -e "\e[34m:
          _ ._  _ , _ ._
        (_ ' ( \`  )_  .__)
      ( (  (    )   \`)  ) _)
     (__ (_   (_ . _) _) ,__)
          ~~\ ' . /~~
        ,::: ;   ; :::,
        ':::::::::::::::'
 ____________/_ __ \____________
|                               |
| Welcome to Guntosos shell.    |
|                               |
|                               |
|        (\(\                   |
|       (-.-)o                  |
|       /_(")(")                |
|_______________________________|
\e[34m:"
echo -e "\e[34m:
          _ ._  _ , _ ._
        (_ ' ( \`  )_  .__)
      ( (  (    )   \`)  ) _)
     (__ (_   (_ . _) _) ,__)
          ~~\\ ' . /~~
        ,::: ;   ; :::,
        ':::::::::::::::'
 ____________/_ __ \____________
|                               |
| Welcome to Guntosos shell.    |
|                               |
|                               |
|        (\\(\\                 |
|       (-.-)o                  |
|       /_(\"(\")               |
|_______________________________|
\e[34m:"

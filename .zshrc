# Set SHELL
export SHELL='/bin/zsh'

# Load the tab completions
autoload -Uz compinit && compinit
# Allow zsh to read bash completions and run bash builtin function `complete`.
autoload bashcompinit && bashcompinit
# Load the colors
autoload colors && colors

# Load the shell profile (shared between bash and zsh)
source $HOME/.shell_profile

# Deduplicate path variable
typeset -U path

# Load zsh scripts from the .lib directory
for file in $HOME/.lib/zsh/*.zsh; do
     source "$file"
done;
unset file;


# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

source $ZSH/oh-my-zsh.sh

export PATH="$HOME/.local/bin:$PATH"
alias fastfetch='~/.config/fastfetch/launch.sh'

~/.config/fastfetch/launch.sh

eval "$(starship init zsh)"

# Transient prompt — replace executed prompt with a colored arrow
typeset -g _transient_prev_ec=0

_transient_precmd() { _transient_prev_ec=$? }
add-zsh-hook precmd _transient_precmd

_transient_zle_finish() {
    local arrow
    [[ $_transient_prev_ec -eq 0 ]] \
        && arrow=$'\e[32m❯\e[0m' \
        || arrow=$'\e[31m❯\e[0m'
    printf '\r\e[2K%s %s' "$arrow" "$BUFFER"
}
zle -N zle-line-finish _transient_zle_finish

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

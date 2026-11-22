# Shell configuration for the Ubuntu chroot on the SM-T970
# Installed as /etc/sm-t970.bashrc by scripts/setup-shell.sh and sourced at the
# end of /root/.bashrc, so it applies to every interactive shell: SSH
# (ConnectBot, PC) and enter-ubuntu.sh.

# UTF-8 without installing the locales package (C.UTF-8 ships with glibc)
export LANG=C.UTF-8

# Reach the native Docker daemon even if sshd_config lacks SetEnv
export DOCKER_HOST="${DOCKER_HOST:-unix:///data/docker/docker.sock}"

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize

# Coloured prompt whatever TERM the client announces (Ubuntu's root .bashrc
# only colours it for TERM=xterm-color, so ConnectBot got a plain prompt).
# "(ubuntu)" makes it obvious that you are inside the chroot, not Android.
PS1='\[\e[0;35m\](ubuntu)\[\e[0m\] \[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
case "$TERM" in
    xterm*|screen*|tmux*|rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;   # window/tab title
esac

# Colours for ls / grep
if command -v dircolors >/dev/null; then
    eval "$(dircolors -b)"
fi
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias grep='grep --color=auto'

# Tab completion (package bash-completion, installed by setup-shell.sh)
if [ -r /usr/share/bash-completion/bash_completion ] && ! shopt -oq posix; then
    . /usr/share/bash-completion/bash_completion
fi

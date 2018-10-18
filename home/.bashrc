source ~/.env.sh

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# only on new shell, fail silently. Must be non-invasive.
[ ! $TMUX ] && ~/bin/server-splash 2>/dev/null

# fix annoying accidental commits and amends
# and other dangerous commands, yubikey OTP, mouse escape codes
export HISTIGNORE='git*--amend*:ls:cd:cccccc*:*reboot*:*halt*:0*:task*'
export HISTCONTROL=ignoredups:ignorespace:erasedups

function _tmux_update_env {
    # tmux must be running
    [ $TMUX ] || return

    # must be remote host (else it clobbers keychain, which runs local only)
    tmux show-environment -g | grep -q SSH_CONNECTION || return

    # when an SSH connection is re-established, so is the agent connection.
    # Reload it automatically.
    eval $(tmux show-environment -s | grep 'SSH_AUTH_SOCK\|DISPLAY')
    echo "Synced env"
}

# Sometimes not set or fully qualified; simple name preferred.
export HOSTNAME=$(hostname -s)

# if you call a different shell, this does not happen automatically. WTF?
export SHELL=$(which bash)

# set from hostname
export SYSTEM_COLOUR=$(~/.local/bin/system-colour $HOSTNAME)
[ $TMUX ] && tmux set -g status-left-bg colour${SYSTEM_COLOUR} &>/dev/null

if [ $USER == root ]; then
    PROMPT_COLOUR=160 # red
else
    PROMPT_COLOUR=$SYSTEM_COLOUR
fi

# AUTOMATIC TMUX
# must not launch tmux inside tmux (no memes please)
# must be installed/single session/no clients
test -z "$TMUX" \
	&& which tmux &> /dev/null \
	&& test $(tmux list-sessions 2> /dev/null | wc -l) -eq 1 \
	&& test $(tmux list-clients 2> /dev/null | wc -l) -eq 0 \
	&& tmux attach


# update the values of LINES and COLUMNS. Automatically
shopt -s checkwinsize

# stop -bash: !": event not found
set +o histexpand

# Bash history sharing. History counter is messed up between sessions and
# commands get lost any other way.
# Explaination: http://unix.stackexchange.com/questions/1288/preserve-bash-history-in-multiple-terminal-windows

HISTSIZE=1000
HISTFILESIZE=$HISTSIZE

# Change default as unconfigured bash could clobber history. Bash can run
# unconfigured if CTRL+C is hit during initialisation.
HISTFILE=~/.history

history() {
	_bash_history_sync
	builtin history "$@"
}

_bash_history_sync() {
	builtin history -a
	HISTFILESIZE=$HISTSIZE
	builtin history -c
	builtin history -r
}

# Useful title for ssh
printf "\033]0;%s\007" $HOSTNAME

# only auto set title based on initial pane
# this detects if the pane is the first in a new window
test $TMUX \
	&& test $(tmux list-panes | wc -l) -eq 1 \
	&& TMUX_PRIMARY_PANE=set

# Update TMUX title with path
# TODO move some to precmd hack
function onprompt {
    # reset the terminal, in case something (such as cat-ing a binary file or
    # failed SSH) sets a strange mode
    stty sane

	# only if TMUX is running, and it's safe to assume the user wants to have the tab automatically named
	if [ -n "$TMUX" ] && [ $TMUX_PRIMARY_PANE ]; then

		# to a clever shorthand representation of the current dir
		LABEL=$(echo $PWD | sed s/[^a-zA-Z0-9\.\/]/-/g | grep -oE '[^\/]+$')

        tmux rename-window "$LABEL"
	fi

	_bash_history_sync
    _tmux_update_env
}

PROMPT_COMMAND=onprompt

# SSH wrapper to magically LOCK tmux title to hostname, if tmux is running
# prefer clear terminal after SSH, on success only
# now with MOAR agent forwarding
function ssh {
	if test $TMUX; then
		# find host from array (in a dumb way) by getting last argument
		# It uses the fact that for implicitly loops over the arguments
		# if you don't tell it what to loop over, and the fact that for
		# loop variables aren't scoped: they keep the last value they
		# were set to
		# http://stackoverflow.com/questions/1853946/getting-the-last-argument-passed-to-a-shell-script
		for host; do true; done

        old_window_name=$(tmux display-message -p '#W')

		printf "\\033k%s\\033\\\\" $host
		command ssh -A "$@"
		printf "\\033k%s\\033\\\\" $old_window_name

	else
		command ssh -A "$@"
	fi
}



# MOAR PROMPT
# with git branch
# make sure the function exists, even if it wasn't included
# this is overridden later
function __git_ps1 {
	return
}

function __p4_ps1 {
	[ $P4CLIENT ] || return
	echo -n " ($P4CLIENT) "
}

function __sa_ps1 {
    # is SSH agent wired in?
    test $SSH_AUTH_SOCK || return
    test -e $SSH_AUTH_SOCK && echo -ne "\033[32m[A]\033[90m "
}

function __exit_warn {
	# test status of last command without affecting it
	status=$?
	test $status -ne 0 \
		&& printf "\n\33[31mExited with status %s\33[m" $status
}

PS1="\$(__exit_warn)\n\[\e[38;5;${PROMPT_COLOUR}m\]\u@\H:\$PWD\[\e[90m\]\$(__git_ps1)\$(__p4_ps1) \$(__sa_ps1)\$(date +%T)\[\e[0m\]\n\$ "

source ~/.aliases

# get new or steal existing tmux
function tm {
	# must not already be inside tmux
	test ! $TMUX || return
	# detach any other clients
	# attach or make new if there isn't one
	tmux attach -d || tmux
}

# slow completion things in background after bashrc is executed
function _deferred {
	# linux / homebrew completions (package: bash-completion)
	[ -f /etc/bash_completion ] && source /etc/bash_completion
    [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

	# latest git completion and PS1
	source ~/.git-completion.sh
	source ~/.git-prompt.sh
    # fish/zsh already have this
    which task > /dev/null && source ~/.task-completions.sh

	# map completion for aliases that need them
	complete -o default -o nospace -F _git g
	complete -o default -o nospace -F _git_diff d
	complete -o default -o nospace -F _git_log l
	complete -o default -o nospace -F _git_status s
	complete -o default -o nospace -F _task n

	# hardcoded ssh completions (known_hosts is encrypted mostly)
	#complete -o default -W 'example.com example.net' ssh scp ping
}

# cd then ls
function cd {
	builtin cd "$@" && ls
}

# fix backspace on some terminals
stty erase ^?
#stty erase ^H

# take over SSH keychain (with gpg-agent soon) but only on local machine, not remote ssh machine
# keychain used in a non-invasive way where it's up to you to add your keys to the agent.
test -x $SSH_CONNECTION && \
    which keychain &>/dev/null && \
    eval `keychain --ignore-missing --nogui --noask --eval --noinherit --agents ssh`

which dircolors &>/dev/null &&  eval $(dircolors ~/.dir_colors)

# Disable stupid flow control. Ctrl+S can disable the terminal, requiring
# Ctrl+Q to restore. It can result in an apparent hung terminal, if
# accidentally pressed.
stty -ixon -ixoff
# https://superuser.com/questions/385175/how-to-reclaim-s-in-zsh
stty stop undef
stty start undef

# fix gpg-agent ncurses passphrase prompt
# https://www.gnupg.org/documentation/manuals/gnupg/Common-Problems.html
export GPG_TTY=$(tty)

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# run the deferred function in the background in this context after bashrc
# http://superuser.com/questions/267771/bash-completion-makes-bash-start-slowly
trap '_deferred 2>/dev/null; trap USR1' USR1
{ sleep 0.1 ; builtin kill -USR1 $$ ; } & disown
trap "~/.local/bin/cleanup-history ~/.history" EXIT

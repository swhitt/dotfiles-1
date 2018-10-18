#!/bin/bash
# This script configures the user account

cd $(dirname $0)

PLATFORM=$(uname)

# task context state is stored in config file, which is about to get clobbered
# so remember it to restore later.
which task &>/dev/null && TASK_CONTEXT=$(task _get rc.context)

test -d ~/.vim/ && rm -rf ~/.vim/
test -d ~/.zsh/ && rm -rf ~/.zsh/

mkdir -p ~/.local/bin
mkdir -p ~/.ssh
chmod 700 ~/.ssh

touch ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
chmod 0700 ~/.gnupg

# trust github pubkey
grep -q github.com ~/.ssh/known_hosts || cat <<EOF >> ~/.ssh/known_hosts
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
EOF

# copy dotfiles separately , normal glob does not match
cp -r home/.??* ~ 2> /dev/null
cp -a etc ~
cp -a bin/* ~/.local/bin/

if [ $PLATFORM == 'Darwin' ]; then
    cp -r home/Library ~
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    chflags nohidden ~/Library/
    # stop preview from opening every PDF you've ever opened every time you view a PDF
    # (how did apple think this was a good idea!?!?!)
    defaults write com.apple.Preview NSQuitAlwaysKeepsWindows -bool false
    # Check for software updates daily, not just once per week
    defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
    # Trackpad: enable tap to click for this user and for the login screen
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    # Disable auto-correct
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
    # Finder: show status bar, path bar, posix path
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
    # When performing a search, search the current folder by default
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    # remove everything from dock (only active applications should be there, as
    # I use spotlight to launch apps with CMD+Space)
    defaults write com.apple.dock persistent-apps -array

    # map caps lock to ESC
    hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}' > /dev/null

    # refresh stuff (killing will presumably make the watchdog restart the application)
    # disabled Dock killing as it makes it jump in front on fullscreen which is irritating
    #killall Dock
    #killall Finder
    #killall SystemUIServer
fi

# reload TMUX config if running inside tmux
if [ -n "$TMUX" ]; then
	tmux source-file ~/.tmux.conf >/dev/null
    export SYSTEM_COLOUR=$(~/.local/bin/system-colour $HOSTNAME)
    tmux set -g status-left-bg colour${SYSTEM_COLOUR} &>/dev/null
fi

if [ $PLATFORM == 'Darwin' ]; then
    # 'Gah! Darwin!? XQuartz crashes in an annoying focus-stealing loop with this .xinirc. Removing...'
    rm ~/.xinitrc
elif [ -n "$DISPLAY" ] && which xrdb &>/dev/null; then
	xrdb -merge ~/.Xresources
	setxkbmap gb
fi

# generate help files (well, tags) for the vim plugins
if which vim &>/dev/null; then
	# -e : ex mode, -s : silent batch mode, -n : no swap
	# must source vimrc in this mode.
	echo 'source ~/.vimrc | call pathogen#helptags()' | vim -es -n -s
fi

if [ -f ~/.bash_history ] && [ ! -f ~/.history ]; then
    cp ~/.bash_history ~/.history
fi
chmod 600 ~/.history

# restore task context (maybe)
test $TASK_CONTEXT && task context $TASK_CONTEXT &>/dev/null

# set caps lock to act as esc if possible
test $DISPLAY && which dconf &> /dev/null && \
    dconf write /org/gnome/desktop/input-sources/xkb-options "['caps:escape']"

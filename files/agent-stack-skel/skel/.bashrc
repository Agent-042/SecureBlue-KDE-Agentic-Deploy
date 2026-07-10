# .bashrc - SecureBlue KDE Agentic Deploy user shell defaults
#
# This file is installed from /etc/skel for new users. It sources the system
# bashrc and then loads any per-application fragments in ~/.bashrc.d/.

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Load per-application fragments from ~/.bashrc.d
if [ -d "$HOME/.bashrc.d" ]; then
    for f in "$HOME/.bashrc.d"/*.sh; do
        [ -f "$f" ] && . "$f"
    done
    unset f
fi

# Sourced by /etc/bash.bashrc in every interactive shell.
# Everyone logs in as `team`. Who you are follows the directory: a shell anywhere in /work/<name> is <name>,
# with that person's logins. That also covers VS Code terminals and agents Herdr resumes after a restart.

me() {
    local name=${1:?usage: me <name>}
    case $name in *[!a-z0-9-]* | -*) echo "me: use a lowercase name, like ann" >&2; return 1 ;; esac
    local p=/work/$name/.devbox
    export DEV=$name
    export PI_CODING_AGENT_DIR=$p/pi COPILOT_HOME=$p/copilot CURSOR_CONFIG_DIR=$p/cursor
    export XDG_DATA_HOME=$p/share # OpenCode keeps its logins in $XDG_DATA_HOME/opencode
    export AZURE_CONFIG_DIR=$p/azure KUBECONFIG=$p/kube/config PUP_HOME=$p/pup
    export AGENT_CLI_CONFIG=$p/agent-cli.toml GIT_CONFIG_GLOBAL=$p/gitconfig
    [ -d "$p" ] || _devbox_join "$name" "$p"
    # The box's instructions, for agents with a per-person instructions file. A link, so image updates reach
    # everyone; skipped when the person has their own file.
    [ -e "$p/pi/AGENTS.md" ] || ln -s /etc/devbox/AGENTS.md "$p/pi/AGENTS.md"
    [ -e "$p/copilot/copilot-instructions.md" ] || ln -s /etc/devbox/AGENTS.md "$p/copilot/copilot-instructions.md"
}

_devbox_join() {
    mkdir -p "$2"/{pi,copilot,cursor,share,azure,kube,pup}
    touch "$GIT_CONFIG_GLOBAL"
    # Editors' git panels don't run a shell, so they read the shared ~/.gitconfig: point it at this person's file
    # for repos in their folder.
    git config --file ~/.gitconfig "includeIf.gitdir:/work/$1/.path" "$GIT_CONFIG_GLOBAL"
    command -v pi >/dev/null || devbox-install-agents
    for agent in pi copilot cursor opencode; do herdr integration install "$agent" >/dev/null; done
    cat <<EOF
Welcome, $1. Your logins live in $2.
  az login --use-device-code
  git config --global user.name "Your Name" && git config --global user.email you@contoso.com
  agent-cli config example > \$AGENT_CLI_CONFIG   # fill in your sections, then: agent-cli doctor
Then sign in to the agents you use: copilot, cursor-agent login, pi (/login), opencode (/connect).
EOF
}

_devbox_follow() {
    local rest=${PWD#/work/}
    [ "$rest" = "$PWD" ] && return
    local name=${rest%%/*}
    case $name in [a-z0-9]*) ;; *) return ;; esac # /work/.home is the shared home, not a person
    if [ "$name" != "${DEV-}" ] && [ -d "/work/$name/.devbox" ]; then me "$name"; fi
}

PROMPT_COMMAND="_devbox_follow${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
PS1='${DEV:+($DEV) }'"$PS1"

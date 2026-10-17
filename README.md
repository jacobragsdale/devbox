# devbox

The team's shared dev box on AKS. You connect over SSH from WSL with Herdr, and with VS Code or Cursor for editing. Agents run in terminals on the box (Cursor's CLI, Copilot, pi, OpenCode) under your own logins, and you can watch and prompt your teammates' agents.

Everyone logs in as one Linux account, `team`. That is what lets Herdr show every agent to everyone, and it also means nothing on the box is private from teammates or their agents. Keep production credentials off it: see [What sharing an account means](#what-sharing-an-account-means).

## Get access

You need namespace access to the cluster: in WSL, `kubectl get pods -n devbox` lists `devbox-0`. If it doesn't, ask whoever runs the box.

To get your key onto the box:

1. If you have no SSH key yet, run `ssh-keygen -t ed25519` in WSL. For VS Code or Cursor, also make one on Windows (in PowerShell, the same command).
2. Open a pull request that adds `people/YOUR_NAME.pub`. Use the lowercase name you'll go by on the box, such as `ann`, and put each public key on its own line: WSL's `~/.ssh/id_ed25519.pub` and, if you use VS Code or Cursor, Windows' `C:\Users\YOU\.ssh\id_ed25519.pub`.
3. Whoever merges it publishes the keys (see [Add or remove a person](#add-or-remove-a-person)). Your key works about a minute later.

## Connect from WSL

To connect:

1. Add the box to `~/.ssh/config` in WSL:

   ```
   Host devbox
     User team
     ProxyCommand kubectl -n devbox exec -i devbox-0 -- nc localhost 2222
     ServerAliveInterval 30
   ```

   SSH runs inside `kubectl exec`, so the box exposes no port.

2. Run `ssh devbox` and accept the host key the first time. If this is your first login, go on to [Set yourself up](#set-yourself-up) in that shell.
3. Add the box to Herdr:

   ```sh
   herdr machine add devbox --label devbox
   ```

   The box shows in Herdr's sidebar next to Local, with everyone's workspaces and agents. Create your workspaces in `/work/YOUR_NAME`.

## Set yourself up

The box tells people apart by directory. A shell in `/work/ann`, or anywhere below it, uses Ann's logins, which live in `/work/ann/.devbox`. The prompt shows whose logins are active, as in `(ann) team@devbox-0:/work/ann$`. Moving into another person's set-up folder switches to them; `/work/.home` and folders outside `/work` keep whoever was active. `me NAME` switches explicitly.

To set yourself up the first time, in an SSH or Herdr shell on the box:

1. Run `me YOUR_NAME`. It creates `/work/YOUR_NAME`, installs the agents if nobody has yet (a minute or two), connects them to Herdr, and prints the next steps.
2. Sign in to Azure: `az login --use-device-code`. This login also gives `git` access to Azure DevOps (no PAT), and agent-cli its Azure access.
3. Set your git name and email: `git config --global user.name "YOUR NAME"`, then the same for `user.email`. On the box, `--global` writes to your own file in `.devbox`.
4. Optional: set up agent-cli, the command-line tool that gives agents Azure DevOps, Azure, Kubernetes, SQL, Oracle, Airflow, Control-M, Confluence and Datadog. `me` points `$AGENT_CLI_CONFIG` at your own file:

   ```sh
   agent-cli config example > $AGENT_CLI_CONFIG
   agent-cli doctor
   ```

   Fill in only the sections you use; `doctor` prints a hint for each failed check. For Kubernetes, `agent-cli aks cluster connect CLUSTER` writes your kubeconfig. For Datadog, put a personal access token in `[datadog]`. TODO: verify whether `pup auth login` works over SSH, which would let you use `token_cmd = "pup auth token"` instead.
5. Sign in to the agents you use: `copilot`, then `/login`; `cursor-agent login`; `pi`, then `/login`; `opencode`, then `/connect`.
6. Clone your repos into `/work/YOUR_NAME`.

From then on, any shell, Herdr pane or editor terminal that starts in `/work/YOUR_NAME` is you.

## Connect VS Code or Cursor

VS Code and Cursor run on Windows, so they read the Windows SSH config, `C:\Users\YOU\.ssh\config`, and use your Windows key. Borrow WSL's kubectl through `wsl.exe`:

```
Host devbox
  User team
  ProxyCommand C:\Windows\System32\wsl.exe kubectl -n devbox exec -i devbox-0 -- nc localhost 2222
  ServerAliveInterval 30
```

`wsl.exe` runs your default distro without your shell profile, so `kubectl` and `kubelogin` must be in a system folder such as `/usr/local/bin` (where `az aks install-cli` puts them). If that doesn't work, install them on Windows too (`az aks install-cli` in PowerShell) and use `ProxyCommand kubectl -n devbox exec -i devbox-0 -- nc localhost 2222` instead. TODO: verify both on Windows.

Connect with Remote-SSH to host `devbox`, then open `/work/YOUR_NAME`. Set yourself up first, because that folder doesn't exist before `me` runs. The first connection installs the editor's server on the box, in the shared home, so the box needs outbound internet. Terminals in your folder use your logins, and the editor's git panel uses your name and Azure login for repos in it. Editor AI features, such as Cursor's agent or Copilot Chat, sign in from your laptop as usual.

## Open a dev server in your browser

VS Code and Cursor forward a port when a dev server on the box starts listening on it. From WSL, forward it yourself, for example for an Angular dev server on port 4200:

```sh
ssh -N -L 4200:localhost:4200 devbox
```

Then open `http://localhost:4200`. WSL forwards localhost to Windows, so the Windows browser works too.

## Work with each other's agents

In Herdr's sidebar, open a teammate's workspace to watch their agent live. On the box, `devbox-who` lists each person's repos, with branch and uncommitted changes, and every agent with its status and folder.

Every agent on the box also gets the box's instructions, [rootfs/etc/devbox/AGENTS.md](rootfs/etc/devbox/AGENTS.md). They tell it who it works for, to stay out of other people's folders and logins, to fetch teammates' commits rather than edit their clones, and how to use `devbox-who` and Herdr. pi and Copilot read it from your `.devbox` folder unless you've put your own instructions file there. OpenCode reads it from its global rules and Cursor's CLI from a user rule (`~/.cursor/rules/devbox.mdc`). Agents built into VS Code or the Cursor editor don't get it, which is one reason to run agents in a terminal.

From any shell:

```sh
herdr --machine devbox agent list
herdr --machine devbox agent read AGENT --lines 80
herdr --machine devbox agent prompt AGENT "bob: which file owns the retry backoff?" --wait
```

`AGENT` is a name from `agent list` or a pane ID such as `w2:p1`. Inside the box, leave out `--machine devbox`. Your agent can run the same commands.

House rules, because Herdr can't tell who typed:

- Name your agents after yourself so `agent list` shows whose is whose: `herdr agent rename w2:p1 ann-copilot`.
- Sign prompts to someone else's agent with your name.
- Prompt only an idle agent, or ask first. A prompt is typed into the other person's terminal, so it mixes with anything they have half typed.
- When two people view the same tab, the last one to click sets its size, and the other person's screen reflows.

## Work on the same code

Each person keeps their own clones in `/work/NAME`. One shared checkout doesn't work with agents: they revert or "fix" each other's half-done edits when tests fail, clean up with `git stash` or `git checkout`, and fight over `node_modules` and build output. To work together instead:

- To look at a teammate's work as it happens, open `/work/ann/app` read-only, or run `git diff` there, and watch their agent in Herdr. A shell in their folder switches to their logins, so don't commit from it.
- To take a teammate's committed work without a push, fetch it from their clone: `git fetch /work/ann/app HEAD`, then `git diff FETCH_HEAD`, merge or cherry-pick. Their uncommitted edits don't come along.
- To mob on one change, pick one person's checkout and one agent that writes; everyone else watches in Herdr and steers through that agent.
- To run several of your own agents at once, give each a worktree in your folder: `git worktree add ../app-retry`. Your logins and git name apply there too.

## Add or remove a person

Publishing keys needs permission to create and update ConfigMaps in the namespace. `deploy/keys.sh` replaces the whole key list, so run it from an up-to-date `main`.

To add a person:

1. Merge their `people/NAME.pub`.
2. Run `deploy/keys.sh`. Set `NAMESPACE` if the namespace isn't `devbox`.

sshd rereads the keys at every login, and the change reaches the pod within about a minute, so nobody's session restarts.

To remove a person, delete their file, run `deploy/keys.sh`, and delete `/work/NAME` on the box. Removing a key alone doesn't lock anyone out who still has namespace access, because `kubectl exec` opens a shell in the pod without SSH. Remove their namespace access too.

## Build and deploy

Prerequisites: push access to the container registry, permission to apply to the namespace, the cluster allowed to pull from the registry (`az aks update --attach-acr`), and outbound HTTPS from the pod. Editors download their server onto the box, and the agents, npm, NuGet, PyPI, Azure DevOps and Datadog are all on the internet.

Before the first deploy, fill in [deploy/devbox.yaml](deploy/devbox.yaml) with what your cloud team gives you: the storage class if it isn't `managed-csi-premium`, and a `nodeSelector` (for example `kubernetes.azure.com/agentpool: POOL`) plus tolerations for the node pool. Then run `deploy/keys.sh`, or the pod waits for its `devbox-keys` ConfigMap.

To deploy a new version:

1. Change the tool versions you want in the `ARG` lines of the [Dockerfile](Dockerfile).
2. Build in the registry: `az acr build -r REGISTRY -t devbox:VERSION .`
3. Set `image:` in [deploy/devbox.yaml](deploy/devbox.yaml) to `REGISTRY.azurecr.io/devbox:VERSION`, then apply it:

   ```sh
   kubectl -n devbox apply -f deploy/devbox.yaml
   ```

`REGISTRY` is the Azure Container Registry name, and `VERSION` the new tag.

A new version restarts the box, so warn the team first. Every agent stops mid-turn. When the first person reconnects, Herdr restores the layout and resumes each agent's conversation, but the interrupted turn doesn't run again: tell your agent to continue. Running processes such as dev servers and test watchers are gone.

To update the agents without a restart, run `devbox-install-agents` on the box. They also update themselves.

## Test a change locally

Try an image change in Docker before it restarts everyone's box. Docker in WSL works.

To test a change:

1. Build the image and start it with a throwaway volume and your own key:

   ```sh
   docker build -t devbox:test .
   mkdir -p /tmp/devbox-keys && cp ~/.ssh/id_ed25519.pub /tmp/devbox-keys/authorized_keys
   docker run -d --name devbox-test -v devbox-test-work:/work -v /tmp/devbox-keys:/etc/devbox/keys:ro devbox:test
   ```

2. Connect the same way people reach the real box, with `docker exec` in place of `kubectl exec`:

   ```sh
   ssh -o ProxyCommand='docker exec -i devbox-test nc localhost 2222' team@devbox-test
   ```

3. On the box, run `me test` and check your change. `devbox-who`, `agent-cli doctor` and `docker restart devbox-test` (to see what survives a restart) cover most of it.
4. Remove it all: `docker rm -f devbox-test && docker volume rm devbox-test-work`.

## What's on the box

| What | Where | Survives a restart |
|---|---|---|
| Your repos, logins and agent history | `/work/YOUR_NAME` | Yes |
| Shared home: Herdr session, editor servers, agents, caches, anything installed with `npm install -g`, `uv tool install` or `dotnet tool install -g` | `/work/.home` | Yes |
| Python (uv), Node 24 (npm, pnpm, yarn), .NET 10 | Image | Pinned in the Dockerfile |
| agent-cli, az, kubectl, kubelogin, pup, Oracle Instant Client, Herdr | Image | Pinned in the Dockerfile |
| git, ripgrep, fd, fzf, jq, htop, nano | Image | |

There is no sudo, and anything changed outside `/work` is lost at the next restart. Tools installed into the shared home are there for everyone. To add another agent, such as Claude Code, install it the same way and run `herdr integration install claude`.

The box gets 2 CPUs and 12 GiB of memory, can burst to 24 GiB, and has a 128 GiB disk ([deploy/devbox.yaml](deploy/devbox.yaml)). Nothing backs up `/work`: push your branches.

## What sharing an account means

Everyone, and every agent, runs as `team`. Herdr shares a session only within one Linux account. With separate Linux users, each person would get their own session that nobody else can see.

Nothing on the box is private: any person or agent can read anyone's logins under `/work/*/.devbox`, use their `az login`, and type into their terminal. The agents' instructions say to leave other people's `.devbox` alone, but that is a request, not a lock. So:

- Use read-only identities here wherever you can: Reader roles, read-only database logins, an Airflow Viewer. agent-cli expects agents to be limited this way.
- Keep production write access and personal secrets off the box.

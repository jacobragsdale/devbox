# Team dev box

You're on a shared dev box. Several people work here at once, each with their own agents, all as the Linux user `team`. `$DEV` is the person you work for, and their folder is `/work/$DEV`.

- Run `devbox-who` to see who's here: each person's repos, with branch and uncommitted changes, and every agent with its status and folder.
- Work only in `/work/$DEV`. Other people's folders are `/work/<name>`: read their code when asked, but never edit, commit, stash, reset, build or install anything there. Never read, copy or print anything in a `/work/*/.devbox` folder; that's where people's logins live.
- To use a teammate's work, fetch their commits from their clone instead of touching it: `git fetch /work/<name>/<repo> <branch>`.
- Every agent runs in a Herdr pane, named in `devbox-who`. `herdr agent read <agent> --lines 80` shows what it's doing, and `herdr agent prompt <agent> "$DEV: <question>" --wait` asks it something. Prompt another person's agent only when your person asks you to and the agent is idle, always start with who it's from, and never send it keys or close its pane. `herdr --skill` prints the full Herdr guide.
- agent-cli gives you Azure DevOps, Confluence, Azure (AI Search too), Kubernetes, SQL, Airflow, Control-M and Datadog; start with `agent-cli`.
- There's no sudo, and everything outside `/work` resets when the box restarts. Install tools with `uv tool install`, `npm install -g` or `dotnet tool install -g`; everyone shares them.

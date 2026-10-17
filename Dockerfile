# syntax=docker/dockerfile:1
# The team's shared dev box: one account (team), sshd on port 2222, the tools people and agents need.
# Tool versions are pinned here. Logins, repos, caches and the self-updating agents live on the /work volume.

ARG UBUNTU=ubuntu:24.04

FROM ${UBUNTU} AS agent-cli
ARG RUST_VERSION=1.99.1
ARG AGENT_CLI_REV=a8907c7ed9e226342f0be90950b0c3885ffc0b3b
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates curl git pkg-config \
 && curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "${RUST_VERSION}"
RUN /root/.cargo/bin/cargo install --locked --git https://github.com/jacobragsdale/agent-cli --rev "${AGENT_CLI_REV}" agent-cli

FROM ${UBUNTU}
ARG NODE_VERSION=24.22.0
ARG KUBECTL_VERSION=1.37.1
ARG KUBELOGIN_VERSION=0.2.21
ARG HERDR_VERSION=0.9.5
ARG PUP_VERSION=2.0.0
ARG ORACLE_IC=2326000
ARG TZ=America/Chicago
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server tini netcat-openbsd ca-certificates curl wget git git-lfs \
      build-essential pkg-config python3 libicu74 libaio1t64 tzdata \
      ripgrep fd-find fzf jq less htop nano unzip zip xz-utils \
 && curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 # Oracle Instant Client looks for libaio.so.1; Ubuntu 24.04 ships it as libaio.so.1t64.
 && ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/x86_64-linux-gnu/libaio.so.1

RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" | tar -xJ -C /opt \
 && mv "/opt/node-v${NODE_VERSION}-linux-x64" /opt/node \
 && PATH=/opt/node/bin:$PATH corepack enable --install-directory /opt/node/bin

RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
 && bash /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet \
 && rm /tmp/dotnet-install.sh

COPY --from=ghcr.io/astral-sh/uv:0.13.1 /uv /uvx /usr/local/bin/

RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && curl -fsSLo /tmp/kubelogin.zip "https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip" \
 && unzip -jq /tmp/kubelogin.zip bin/linux_amd64/kubelogin -d /usr/local/bin \
 && curl -fsSLo /usr/local/bin/herdr "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-x86_64" \
 && mkdir -p /opt/pup \
 && curl -fsSL "https://github.com/DataDog/pup/releases/download/v${PUP_VERSION}/pup_${PUP_VERSION}_Linux_x86_64.tar.gz" | tar -xz -C /opt/pup \
 && curl -fsSLo /tmp/instantclient.zip "https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_IC}/instantclient-basic-linux.x64-23.26.0.0.0.zip" \
 && unzip -q /tmp/instantclient.zip -d /opt/oracle \
 && echo /opt/oracle/instantclient_23_26 > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/herdr \
 && rm /tmp/kubelogin.zip /tmp/instantclient.zip

COPY --from=agent-cli /root/.cargo/bin/agent-cli /usr/local/bin/agent-cli
COPY rootfs/ /

# Ubuntu's image already has uid 1000 as `ubuntu`. The home is on the volume, so useradd doesn't create it.
RUN userdel -r ubuntu \
 && useradd -u 1000 -U -d /work/.home -M -s /bin/bash team \
 && mkdir -p /work && chown team:team /work \
 && echo '. /etc/devbox/shell.sh' >> /etc/bash.bashrc \
 # Cursor reads user rules as .mdc files with frontmatter; this one always applies.
 && { printf -- '---\ndescription: The shared dev box, its people and their agents\nalwaysApply: true\n---\n\n'; \
      cat /etc/devbox/AGENTS.md; } > /etc/devbox/devbox.mdc

USER team
WORKDIR /work
EXPOSE 2222
ENTRYPOINT ["tini", "--", "devbox-entrypoint"]

#!/usr/bin/env bash
set -uo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

# ── sudo: authenticate once, keep alive ────────────────────────────────────────
info "Requesting sudo — you will only be asked once."
sudo -v
# Refresh the sudo timestamp in the background for the duration of the script
( while true; do sudo -n true; sleep 50; done ) &
SUDO_KEEPER_PID=$!
trap 'kill $SUDO_KEEPER_PID 2>/dev/null' EXIT

# ── helpers ────────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }
rpm_installed()  { rpm -q "$1" &>/dev/null; }
snap_installed() { snap list "$1" &>/dev/null 2>&1; }

# ── 1. System packages (dnf — install only missing) ───────────────────────────
section "System packages via dnf"
DNF_PACKAGES=(
  zsh
  git curl wget unzip zip tar
  java-21-openjdk java-21-openjdk-devel
  python3 python3-pip
  sqlite
  postgresql postgresql-server postgresql-contrib
  vim kitty
  neovim ripgrep fd-find lazygit
  gcc gcc-c++ make
  dnf-plugins-core
)

MISSING=()
for pkg in "${DNF_PACKAGES[@]}"; do
  if rpm_installed "$pkg"; then
    info "Already installed: $pkg — skipping"
  else
    MISSING+=("$pkg")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  info "Installing: ${MISSING[*]}"
  sudo dnf install -y --skip-unavailable "${MISSING[@]}" \
    || warn "dnf exited non-zero — some packages may not have installed."
else
  info "All system packages already installed."
fi

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
section "Oh My Zsh"
hash -r  # refresh command lookup after dnf install
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  ZSH= sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  info "Oh My Zsh installed."
else
  info "Oh My Zsh already installed — skipping."
fi

# Install zsh-syntax-highlighting plugin (third-party)
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  info "zsh-syntax-highlighting plugin installed."
else
  info "zsh-syntax-highlighting already installed — skipping."
fi

# Install zsh-history-substring-search plugin (third-party)
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]]; then
  git clone https://github.com/zsh-users/zsh-history-substring-search.git \
    "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
  info "zsh-history-substring-search plugin installed."
else
  info "zsh-history-substring-search already installed — skipping."
fi

# ── Nerd Font ────────────────────────────────────────────────────────────────
section "Nerd Font (JetBrains Mono)"
FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
  mkdir -p "$FONT_DIR"
  NF_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/JetBrainsMono.tar.xz" \
    -o /tmp/JetBrainsMono.tar.xz
  tar -xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR"
  rm -f /tmp/JetBrainsMono.tar.xz
  fc-cache -fv
  info "JetBrains Mono Nerd Font installed."
else
  info "JetBrains Mono Nerd Font already installed — skipping."
fi

# ── Starship prompt ──────────────────────────────────────────────────────────
section "Starship"
if ! command_exists starship; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
  info "Starship installed."
else
  info "Starship $(starship --version) already installed — skipping."
fi

# Set oh-my-zsh plugins in .zshrc
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
  sed -i 's/^plugins=(.*/plugins=(git zsh-history-substring-search zsh-syntax-highlighting)/' "$ZSHRC"
fi

# ── 2. PostgreSQL: initialise if needed ────────────────────────────────────────
section "PostgreSQL"
if systemctl is-active --quiet postgresql; then
  info "PostgreSQL already running — skipping."
else
  if command -v postgresql-setup &>/dev/null; then
    sudo postgresql-setup --initdb 2>/dev/null || warn "PostgreSQL initdb skipped (already initialised?)"
  elif [[ -x /usr/libexec/postgresql-setup ]]; then
    sudo /usr/libexec/postgresql-setup initdb 2>/dev/null || warn "PostgreSQL initdb skipped (already initialised?)"
  else
    warn "postgresql-setup not found — skipping initdb."
  fi
  sudo systemctl enable --now postgresql || warn "Failed to start PostgreSQL."
  info "PostgreSQL setup done."
fi

# ── 3. SDKMAN + Java (adoptium temurin LTS) ───────────────────────────────────
section "SDKMAN"
if [[ ! -d "$HOME/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
  info "SDKMAN installed."
else
  info "SDKMAN already installed — skipping."
fi
# shellcheck disable=SC1090
# SDKMAN scripts are not compatible with set -u (unbound variables)
set +u
source "$HOME/.sdkman/bin/sdkman-init.sh"

if [[ ! -d "$HOME/.sdkman/candidates/java/current" ]]; then
  sdk install java         # installs the default/latest LTS
  info "Java (SDKMAN) installed."
else
  info "Java (SDKMAN) already installed — skipping."
fi

if [[ ! -d "$HOME/.sdkman/candidates/kotlin/current" ]]; then
  sdk install kotlin
  info "Kotlin (SDKMAN) installed."
else
  info "Kotlin (SDKMAN) already installed — skipping."
fi
set -u

# ── 4. Rust + cargo (via rustup — https://rust-lang.org/tools/install) ─────────
section "Rust"
if [[ ! -x "$HOME/.cargo/bin/cargo" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
  info "Rust $(rustc --version) installed."
else
  export PATH="$HOME/.cargo/bin:$PATH"
  info "Rust $(rustc --version) already installed — skipping."
fi

# ── 5. Leiningen (Clojure) ─────────────────────────────────────────────────────
section "Leiningen (Clojure)"
mkdir -p "$HOME/.local/bin"
if ! command_exists lein; then
  curl -fsSL https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein \
    -o "$HOME/.local/bin/lein"
  chmod +x "$HOME/.local/bin/lein"
  export PATH="$HOME/.local/bin:$PATH"
  lein version   # triggers self-install
  info "Leiningen installed."
else
  info "Leiningen already installed — skipping."
fi

# ── 6. Babashka ────────────────────────────────────────────────────────────────
section "Babashka"
if ! command_exists bb; then
  BB_VERSION=$(curl -s https://api.github.com/repos/babashka/babashka/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  curl -fsSL "https://github.com/babashka/babashka/releases/download/v${BB_VERSION}/babashka-${BB_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/bb"
  info "Babashka $(bb --version) installed."
else
  info "Babashka $(bb --version) already installed — skipping."
fi

# ── 7. NVM + Node (latest LTS) ────────────────────────────────────────────────
section "NVM + Node"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  info "NVM installed."
else
  info "NVM already installed — skipping."
fi
# shellcheck disable=SC1090
set +u; source "$NVM_DIR/nvm.sh"; set -u

if ! command_exists node; then
  nvm install --lts
  nvm use --lts
  nvm alias default 'lts/*'
  info "Node $(node --version) / npm $(npm --version) installed."
else
  info "Node $(node --version) / npm $(npm --version) already installed — skipping."
fi

# ── 8. Vite (global) ──────────────────────────────────────────────────────────
section "Vite"
if ! command_exists vite; then
  npm install -g vite
  info "Vite installed."
else
  info "Vite already installed — skipping."
fi

# ── 9. GitHub Copilot CLI ─────────────────────────────────────────────────────
section "GitHub Copilot CLI"
if ! command_exists github-copilot-cli; then
  npm install -g @github/copilot
  warn "Run 'github-copilot auth' after this script to authenticate with GitHub."
  info "Copilot CLI installed."
else
  info "GitHub Copilot CLI already installed — skipping."
fi

# ── 10. Slack (snap) ──────────────────────────────────────────────────────────
section "Slack"
# snapd is not in Fedora's default repos — install via dnf if missing
if ! rpm_installed snapd; then
  sudo dnf install -y snapd || {
    warn "snapd not in default repos. Installing via COPR..."
    sudo dnf copr enable -y nickavem/snapd 2>/dev/null \
      && sudo dnf install -y snapd \
      || warn "snapd install failed — Slack/Postman snaps will not work."
  }
fi
sudo systemctl enable --now snapd.socket || warn "Failed to enable snapd."
# SELinux symlink needed on Fedora
if [[ ! -L /snap ]]; then
  sudo ln -sf /var/lib/snapd/snap /snap
fi
if snap_installed slack; then
  info "Slack already installed — skipping."
else
  warn "A reboot (or re-login) may be required before snap works on Fedora."
  sudo snap install slack --classic || warn "Slack snap install failed — try again after reboot."
  info "Slack installed."
fi

# ── 11. Chrome ────────────────────────────────────────────────────────────────
section "Google Chrome"
if ! command_exists google-chrome; then
  sudo dnf config-manager --set-enabled google-chrome 2>/dev/null || \
    sudo dnf config-manager addrepo \
      --from-repofile=https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome.repo
  sudo dnf install -y google-chrome-stable
  info "Chrome installed."
else
  info "Chrome already installed — skipping."
fi

# ── 12. Postman ───────────────────────────────────────────────────────────────
section "Postman"
if snap_installed postman || command_exists postman; then
  info "Postman already installed — skipping."
else
  sudo snap install postman || warn "Postman snap install failed — try again after reboot."
  info "Postman installed."
fi

# ── LazyVim ──────────────────────────────────────────────────────────────────
section "LazyVim"
if [[ -d "$HOME/.config/nvim" ]] && \
   grep -q "LazyVim" "$HOME/.config/nvim/lua/config/lazy.lua" 2>/dev/null; then
  info "LazyVim already installed — skipping."
else
  # Back up existing Neovim config, then clone the LazyVim starter
  for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [[ -d "$d" ]] && mv "$d" "${d}.bak.$(date +%s)"
  done
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  info "LazyVim starter config installed. Run 'nvim' to finish plugin setup."
fi

# ── PATH additions to shell rc ────────────────────────────────────────────────
section "Shell profile updates"
SHELL_RC="$HOME/.bashrc"
[[ "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"

add_to_rc() {
  grep -qF "$1" "$SHELL_RC" || echo "$1" >> "$SHELL_RC"
}

add_to_rc 'export PATH="$HOME/.local/bin:$PATH"'
add_to_rc 'export PATH="$HOME/.cargo/bin:$PATH"'
add_to_rc 'export NVM_DIR="$HOME/.nvm"'
add_to_rc '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"'
add_to_rc '[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"'
add_to_rc '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'

# ── Done ──────────────────────────────────────────────────────────────────────
section "All done 🎉"
cat <<'EOF'

Next steps:
  1. Open a new terminal (or run `source ~/.zshrc`) to reload PATH.
  2. Run `github-copilot auth` to authenticate Copilot CLI with GitHub.
  3. If Slack/Postman (snap) failed, reboot first, then re-run those snap lines.
  4. `sdk list java` to see and install other JDK versions via SDKMAN.

EOF

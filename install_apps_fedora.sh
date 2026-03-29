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

# ── 1. System packages (one dnf call) ──────────────────────────────────────────
section "System packages via dnf"
sudo dnf install -y \
  zsh \
  git curl wget unzip zip tar \
  java-21-openjdk java-21-openjdk-devel \
  kotlin \
  python3 python3-pip \
  sqlite \
  postgresql postgresql-server postgresql-contrib \
  vim kitty \
  neovim ripgrep fd-find lazygit \
  gcc gcc-c++ make \
  snapd \
  dnf-plugins-core

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
section "Oh My Zsh"
hash -r  # refresh command lookup after dnf install
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  ZSH= sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
info "Oh My Zsh installed."

# ── 2. PostgreSQL: initialise if needed ────────────────────────────────────────
section "PostgreSQL"
if ! sudo postgresql-setup --initdb 2>/dev/null; then
  warn "PostgreSQL initdb skipped (already initialised?)"
fi
sudo systemctl enable --now postgresql || warn "Failed to start PostgreSQL."
info "PostgreSQL setup done."

# ── 3. SDKMAN + Java (adoptium temurin LTS) ───────────────────────────────────
section "SDKMAN"
if [[ ! -d "$HOME/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
fi
# shellcheck disable=SC1090
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java         # installs the default/latest LTS
sdk install kotlin       # sdkman-managed kotlin as well (optional alongside dnf)
info "SDKMAN + Java installed."

# ── 4. Rust + cargo ────────────────────────────────────────────────────────────
section "Rust"
if ! command_exists rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env"
rustup update stable
info "Rust $(rustc --version) installed."

# ── 5. Leiningen (Clojure) ─────────────────────────────────────────────────────
section "Leiningen (Clojure)"
mkdir -p "$HOME/.local/bin"
if ! command_exists lein; then
  curl -fsSL https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein \
    -o "$HOME/.local/bin/lein"
  chmod +x "$HOME/.local/bin/lein"
  export PATH="$HOME/.local/bin:$PATH"
  lein version   # triggers self-install
fi
info "Leiningen installed."

# ── 6. Babashka ────────────────────────────────────────────────────────────────
section "Babashka"
if ! command_exists bb; then
  BB_VERSION=$(curl -s https://api.github.com/repos/babashka/babashka/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  curl -fsSL "https://github.com/babashka/babashka/releases/download/v${BB_VERSION}/babashka-${BB_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/bb"
fi
info "Babashka $(bb --version) installed."

# ── 7. NVM + Node (latest LTS) ────────────────────────────────────────────────
section "NVM + Node"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
# shellcheck disable=SC1090
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'
info "Node $(node --version) / npm $(npm --version) installed."

# ── 8. Vite (global) ──────────────────────────────────────────────────────────
section "Vite"
npm install -g vite
info "Vite $(vite --version) installed."

# ── 9. GitHub Copilot CLI ─────────────────────────────────────────────────────
section "GitHub Copilot CLI"
npm install -g @githubnext/github-copilot-cli
# Authenticate interactively after the script finishes — not automatable
warn "Run 'github-copilot-cli auth' after this script to authenticate with GitHub."
info "Copilot CLI installed."

# ── 10. Slack (snap) ──────────────────────────────────────────────────────────
section "Slack"
sudo systemctl enable --now snapd.socket || warn "Failed to enable snapd."
# SELinux symlink needed on Fedora
if [[ ! -L /snap ]]; then
  sudo ln -sf /var/lib/snapd/snap /snap
fi
warn "A reboot (or re-login) may be required before snap works on Fedora."
sudo snap install slack --classic || warn "Slack snap install failed — try again after reboot."

# ── 11. Chrome ────────────────────────────────────────────────────────────────
section "Google Chrome"
if ! command_exists google-chrome; then
  sudo dnf config-manager --set-enabled google-chrome 2>/dev/null || \
    sudo dnf config-manager addrepo \
      --from-repofile=https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome.repo
  sudo dnf install -y google-chrome-stable
fi
info "Chrome installed."

# ── 12. Postman ───────────────────────────────────────────────────────────────
section "Postman"
if ! command_exists postman; then
  sudo snap install postman || warn "Postman snap install failed — try again after reboot."
fi
info "Postman installed."

# ── LazyVim ──────────────────────────────────────────────────────────────────
section "LazyVim"
# Back up existing Neovim config, then clone the LazyVim starter
if [[ ! -d "$HOME/.config/nvim/.git" ]] || \
   ! grep -q "LazyVim" "$HOME/.config/nvim/lua/config/lazy.lua" 2>/dev/null; then
  for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [[ -d "$d" ]] && mv "$d" "${d}.bak.$(date +%s)"
  done
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
fi
info "LazyVim starter config installed. Run 'nvim' to finish plugin setup."

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
  1. Run `source ~/.bashrc` (or open a new terminal) to reload PATH.
  2. Run `github-copilot-cli auth` to authenticate Copilot CLI with GitHub.
  3. If Slack/Postman (snap) failed, reboot first, then re-run those snap lines.
  4. `sdk list java` to see and install other JDK versions via SDKMAN.

EOF

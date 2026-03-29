#!/usr/bin/env bash
set -uo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

# ── helpers ────────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
section "Homebrew"
if ! command_exists brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
brew update
info "Homebrew ready."

# ── 2. System packages (one brew call) ───────────────────────────────────────
section "System packages via brew"
brew install \
  git curl wget unzip zip \
  openjdk@21 \
  kotlin \
  python@3 \
  sqlite \
  postgresql@17 \
  vim neovim ripgrep fd lazygit \
  gcc make

brew install --cask kitty

# ── 3. PostgreSQL: start service ─────────────────────────────────────────────
section "PostgreSQL"
brew services start postgresql@17
info "PostgreSQL enabled and started."

# ── 4. Oh My Zsh ────────────────────────────────────────────────────────────
section "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
info "Oh My Zsh installed."

# ── 5. SDKMAN + Java ────────────────────────────────────────────────────────
section "SDKMAN"
if [[ ! -d "$HOME/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
fi
# shellcheck disable=SC1090
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
sdk install kotlin
info "SDKMAN + Java installed."

# ── 6. Rust + cargo ─────────────────────────────────────────────────────────
section "Rust"
if ! command_exists rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env"
rustup update stable
info "Rust $(rustc --version) installed."

# ── 7. Leiningen (Clojure) ──────────────────────────────────────────────────
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

# ── 8. Babashka ─────────────────────────────────────────────────────────────
section "Babashka"
if ! command_exists bb; then
  brew install borkdude/brew/babashka
fi
info "Babashka $(bb --version) installed."

# ── 9. NVM + Node (latest LTS) ──────────────────────────────────────────────
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

# ── 10. Vite (global) ───────────────────────────────────────────────────────
section "Vite"
npm install -g vite
info "Vite $(vite --version) installed."

# ── 11. GitHub Copilot CLI ──────────────────────────────────────────────────
section "GitHub Copilot CLI"
npm install -g @githubnext/github-copilot-cli
warn "Run 'github-copilot-cli auth' after this script to authenticate with GitHub."
info "Copilot CLI installed."

# ── 12. Slack ────────────────────────────────────────────────────────────────
section "Slack"
if ! brew list --cask slack &>/dev/null; then
  brew install --cask slack
fi
info "Slack installed."

# ── 13. Chrome ───────────────────────────────────────────────────────────────
section "Google Chrome"
if ! brew list --cask google-chrome &>/dev/null; then
  brew install --cask google-chrome
fi
info "Chrome installed."

# ── 14. Postman ──────────────────────────────────────────────────────────────
section "Postman"
if ! brew list --cask postman &>/dev/null; then
  brew install --cask postman
fi
info "Postman installed."

# ── LazyVim ──────────────────────────────────────────────────────────────────
section "LazyVim"
if [[ ! -d "$HOME/.config/nvim/.git" ]] || \
   ! grep -q "LazyVim" "$HOME/.config/nvim/lua/config/lazy.lua" 2>/dev/null; then
  for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [[ -d "$d" ]] && mv "$d" "${d}.bak.$(date +%s)"
  done
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
fi
info "LazyVim starter config installed. Run 'nvim' to finish plugin setup."

# ── PATH additions to shell rc ───────────────────────────────────────────────
section "Shell profile updates"
SHELL_RC="$HOME/.zshrc"

add_to_rc() {
  grep -qF "$1" "$SHELL_RC" || echo "$1" >> "$SHELL_RC"
}

# Homebrew (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  add_to_rc 'eval "$(/opt/homebrew/bin/brew shellenv)"'
fi
add_to_rc 'export PATH="$HOME/.local/bin:$PATH"'
add_to_rc 'export PATH="$HOME/.cargo/bin:$PATH"'
add_to_rc 'export NVM_DIR="$HOME/.nvm"'
add_to_rc '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"'
add_to_rc '[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"'
add_to_rc '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'

# ── Done ─────────────────────────────────────────────────────────────────────
section "All done 🎉"
cat <<'EOF'

Next steps:
  1. Open a new terminal to reload PATH.
  2. Run `github-copilot-cli auth` to authenticate Copilot CLI with GitHub.
  3. `sdk list java` to see and install other JDK versions via SDKMAN.

EOF

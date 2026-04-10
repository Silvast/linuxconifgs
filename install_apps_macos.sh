#!/usr/bin/env bash
set -uo pipefail

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}══ $* ══${NC}"; }

# ── helpers ────────────────────────────────────────────────────────────────────
command_exists()      { command -v "$1" &>/dev/null; }
brew_installed()      { brew list "$1" &>/dev/null 2>&1; }
brew_cask_installed() { brew list --cask "$1" &>/dev/null 2>&1; }

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
section "Homebrew"
if ! command_exists brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  info "Homebrew installed."
else
  info "Homebrew already installed — skipping."
fi
brew update

# ── 2. System packages (brew — install only missing) ────────────────────────
section "System packages via brew"
BREW_PACKAGES=(
  git curl wget unzip zip
  openjdk@21
  kotlin
  python@3
  sqlite
  postgresql@17
  vim neovim ripgrep fd lazygit
  gcc make
)

MISSING=()
for pkg in "${BREW_PACKAGES[@]}"; do
  if brew_installed "$pkg"; then
    info "Already installed: $pkg — skipping"
  else
    MISSING+=("$pkg")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  info "Installing: ${MISSING[*]}"
  brew install "${MISSING[@]}"
else
  info "All brew formulae already installed."
fi

if ! brew_cask_installed kitty; then
  brew install --cask kitty
  info "Kitty installed."
else
  info "Kitty already installed — skipping."
fi

# ── 3. PostgreSQL: start service ─────────────────────────────────────────────
section "PostgreSQL"
if pgrep -x postgres &>/dev/null; then
  info "PostgreSQL already running — skipping."
else
  brew services start postgresql@17
  info "PostgreSQL enabled and started."
fi

# ── 4. Oh My Zsh ────────────────────────────────────────────────────────────
section "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
if ! brew_cask_installed font-jetbrains-mono-nerd-font; then
  brew install --cask font-jetbrains-mono-nerd-font
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
  sed -i '' 's/^plugins=(.*/plugins=(git zsh-history-substring-search zsh-syntax-highlighting)/' "$ZSHRC"
fi

# ── 5. SDKMAN + Java ────────────────────────────────────────────────────────
section "SDKMAN"
if [[ ! -d "$HOME/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
  info "SDKMAN installed."
else
  info "SDKMAN already installed — skipping."
fi
# shellcheck disable=SC1090
set +u; source "$HOME/.sdkman/bin/sdkman-init.sh"; set -u

if [[ ! -d "$HOME/.sdkman/candidates/java/current" ]]; then
  sdk install java
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

# ── 6. Rust + cargo (via rustup — https://rust-lang.org/tools/install) ──────
section "Rust"
if [[ ! -x "$HOME/.cargo/bin/cargo" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
  info "Rust $(rustc --version) installed."
else
  export PATH="$HOME/.cargo/bin:$PATH"
  info "Rust $(rustc --version) already installed — skipping."
fi

# ── 7. Leiningen (Clojure) ──────────────────────────────────────────────────
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

# ── 8. Babashka ─────────────────────────────────────────────────────────────
section "Babashka"
if ! command_exists bb; then
  brew install borkdude/brew/babashka
  info "Babashka installed."
else
  info "Babashka $(bb --version) already installed — skipping."
fi

# ── 9. NVM + Node (latest LTS) ──────────────────────────────────────────────
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

# ── 10. Vite (global) ───────────────────────────────────────────────────────
section "Vite"
if ! command_exists vite; then
  npm install -g vite
  info "Vite installed."
else
  info "Vite already installed — skipping."
fi

# ── 11. GitHub Copilot CLI ──────────────────────────────────────────────────
section "GitHub Copilot CLI"
if ! command_exists github-copilot-cli; then
  npm install -g @githubnext/github-copilot-cli
  warn "Run 'github-copilot-cli auth' after this script to authenticate with GitHub."
  info "Copilot CLI installed."
else
  info "GitHub Copilot CLI already installed — skipping."
fi

# ── 12. Slack ────────────────────────────────────────────────────────────────
section "Slack"
if ! brew_cask_installed slack; then
  brew install --cask slack
  info "Slack installed."
else
  info "Slack already installed — skipping."
fi

# ── 13. Chrome ───────────────────────────────────────────────────────────────
section "Google Chrome"
if ! brew_cask_installed google-chrome; then
  brew install --cask google-chrome
  info "Chrome installed."
else
  info "Chrome already installed — skipping."
fi

# ── 14. Postman ──────────────────────────────────────────────────────────────
section "Postman"
if ! brew_cask_installed postman; then
  brew install --cask postman
  info "Postman installed."
else
  info "Postman already installed — skipping."
fi

# ── LazyVim ──────────────────────────────────────────────────────────────────
section "LazyVim"
if [[ -d "$HOME/.config/nvim" ]] && \
   grep -q "LazyVim" "$HOME/.config/nvim/lua/config/lazy.lua" 2>/dev/null; then
  info "LazyVim already installed — skipping."
else
  for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    [[ -d "$d" ]] && mv "$d" "${d}.bak.$(date +%s)"
  done
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  info "LazyVim starter config installed. Run 'nvim' to finish plugin setup."
fi

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

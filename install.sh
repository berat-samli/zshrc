#!/usr/bin/env bash
#
# Yeni bir macOS makinesini bu .zshrc'nin beklediği hale getirir.
#
#   ./install.sh              # kur
#   ./install.sh --dry-run    # sadece ne yapacağını göster
#   ./install.sh --no-cask    # GUI uygulamaları ve fontları atla
#
# Idempotent: zaten kurulu olanı atlar, tekrar tekrar çalıştırılabilir.

set -euo pipefail

DRY_RUN=0
WITH_CASKS=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-cask) WITH_CASKS=0 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bilinmeyen secenek: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

# --- cikti --------------------------------------------------------------
if [[ -t 1 ]]; then
  C_STEP=$'\033[34m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_STEP=''; C_OK=''; C_WARN=''; C_OFF=''
fi
step() { printf '%s::%s %s\n' "$C_STEP" "$C_OFF" "$*"; }
ok()   { printf '%sok%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()  { printf '%s!!%s %s\n' $'\033[31m' "$C_OFF" "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '   [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- on kontroller ------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "bu script sadece macOS icin"
[[ -f "$SCRIPT_DIR/.zshrc" ]] || die "$SCRIPT_DIR/.zshrc bulunamadi"

(( DRY_RUN )) && warn "DRY RUN - hicbir sey degistirilmeyecek"

# --- homebrew -----------------------------------------------------------
step "homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "zaten kurulu: $(command -v brew)"
else
  run /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon'da brew PATH'te olmayabilir
if [[ -x /opt/homebrew/bin/brew ]] && ! command -v brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
(( DRY_RUN )) || command -v brew >/dev/null 2>&1 || die "brew PATH'te bulunamadi"

# --- tap'ler ------------------------------------------------------------
TAPS=(
  derailed/k9s
  hashicorp/tap
  homebrew/services
  hudochenkov/sshpass
  nats-io/nats-tools
  skyhook-io/tap
)

step "tap'ler"
if (( DRY_RUN )); then
  printf '   [dry-run] brew tap %s\n' "${TAPS[@]}"
else
  existing_taps="$(brew tap)"
  for t in "${TAPS[@]}"; do
    if grep -qx "$t" <<<"$existing_taps"; then
      ok "$t"
    else
      brew tap "$t"
    fi
  done
fi

# --- formuller ----------------------------------------------------------
# .zshrc'nin dogrudan ihtiyac duyduklari once gelir, gerisi gunluk arac seti.
FORMULAE=(
  # .zshrc'nin bagimliliklari
  powerlevel10k zsh-autosuggestions direnv kubie kubectx
  hudochenkov/sshpass/sshpass jq coreutils

  # kubernetes
  argocd cilium-cli derailed/k9s/k9s helm@3 kargo kubent kustomize
  litmusctl minikube stern

  # bulut / altyapi
  ansible crane dive grype infracost lego openbao opentofu skopeo sops
  trivy yamllint yq

  # diller / toolchain
  cmake go go-task llvm@18 make maven node@22 openjdk@17 pyenv
  python@3.12 python@3.13 rustup uv yarn

  # veritabani
  minio-mc mongosh mysql-client nats-server postgresql@14 postgresql@17
  postgresql@18 redis

  # ag / vpn
  nginx nmap openfortivpn openvpn telnet websocat wget

  # kabuk / gunluk
  btop fd fzf gh glab htop neovim pinentry-mac ripgrep rover rtk
  skyhook-io/tap/radar watch

  # ekstra
  cmatrix cocoapods cowsay ffmpeg screenfetch
)

step "formuller (${#FORMULAE[@]} adet)"
if (( DRY_RUN )); then
  printf '   [dry-run] brew install %s\n' "${FORMULAE[*]}"
else
  installed="$(brew list --formula --full-name)"
  to_install=()
  for f in "${FORMULAE[@]}"; do
    short="${f##*/}"
    if grep -qx -e "$f" -e "$short" <<<"$installed"; then
      continue
    fi
    to_install+=("$f")
  done
  if (( ${#to_install[@]} )); then
    echo "   kurulacak: ${to_install[*]}"
    # tek tek kur: bir formul patlarsa digerleri devam etsin
    for f in "${to_install[@]}"; do
      brew install "$f" || warn "$f kurulamadi, atlandi"
    done
  else
    ok "hepsi kurulu"
  fi
fi

# --- cask'lar -----------------------------------------------------------
CASKS=(
  font-jetbrains-mono-nerd-font
  font-meslo-lg-nerd-font
  temurin@17
  mysql-shell
  apache-directory-studio
)

if (( WITH_CASKS )); then
  step "cask'lar"
  if (( DRY_RUN )); then
    printf '   [dry-run] brew install --cask %s\n' "${CASKS[*]}"
  else
    installed_casks="$(brew list --cask 2>/dev/null || true)"
    for c in "${CASKS[@]}"; do
      if grep -qx "$c" <<<"$installed_casks"; then
        ok "$c"
      else
        brew install --cask "$c" || warn "$c kurulamadi, atlandi"
      fi
    done
  fi
else
  step "cask'lar atlandi (--no-cask)"
fi

# --- oh-my-zsh ----------------------------------------------------------
step "oh-my-zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  ok "zaten kurulu"
else
  # KEEP_ZSHRC: kendi .zshrc'mizi ezmesin
  run env KEEP_ZSHRC=yes RUNZSH=no CHSH=no /bin/sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# --- .zshrc -------------------------------------------------------------
step ".zshrc"
if [[ -f "$HOME/.zshrc" ]] && ! cmp -s "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"; then
  warn "mevcut ~/.zshrc farkli, yedek: ~/.zshrc.bak.$TS"
  run cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$TS"
fi
run cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
ok "~/.zshrc yazildi"

# --- .zshrc.local sablonu ----------------------------------------------
step "~/.zshrc.local"
if [[ -f "$HOME/.zshrc.local" ]]; then
  ok "zaten var, dokunulmadi"
elif (( DRY_RUN )); then
  printf '   [dry-run] ~/.zshrc.local sablonu olusturulacak\n'
else
  cat > "$HOME/.zshrc.local" <<'LOCAL'
# Bu dosya git'e girmez. Kuruma ozel degerler burada.
# Eski makineden gercek degerleri tasi.
export ODEAL_AD_USER=''      # ornek: ad.soyad@sirket.local
export ODEAL_MAIL_USER=''    # ornek: ad.soyad@sirket.com
export INVENTORY_IMAGE=''    # ornek: harbor.sirket.com/devops/inventory:vX.Y.Z
LOCAL
  chmod 600 "$HOME/.zshrc.local"
  warn "~/.zshrc.local sablon olarak olusturuldu - degerleri doldurman lazim"
fi

# --- npm global ---------------------------------------------------------
step "npm global paketleri"
NPM_GLOBALS=(@anthropic-ai/claude-code kubernetes-mcp-server gitnexus)
if (( DRY_RUN )); then
  printf '   [dry-run] npm i -g %s\n' "${NPM_GLOBALS[*]}"
elif command -v npm >/dev/null 2>&1; then
  npm install -g "${NPM_GLOBALS[@]}" || warn "npm global kurulumu basarisiz"
else
  warn "npm yok (node@22 PATH'e link'li mi?), atlandi"
fi

# --- krew + kubectl plugin'leri ----------------------------------------
step "krew"
if (( DRY_RUN )); then
  printf '   [dry-run] krew + plugin kurulumu\n'
elif ! command -v kubectl >/dev/null 2>&1; then
  warn "kubectl yok, krew atlandi"
else
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  if ! kubectl krew version >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    (
      cd "$tmp"
      OS="$(uname | tr '[:upper:]' '[:lower:]')"
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')"
      KREW="krew-${OS}_${ARCH}"
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
      tar zxf "${KREW}.tar.gz"
      "./${KREW}" install krew
    ) || warn "krew kurulamadi"
    rm -rf "$tmp"
  else
    ok "krew zaten kurulu"
  fi

  for p in pod-logs popeye print-env resource-capacity who-can; do
    kubectl krew install "$p" 2>/dev/null || true
  done
fi

# --- pyenv --------------------------------------------------------------
step "pyenv python"
PY_VERSION=3.12.6
if (( DRY_RUN )); then
  printf '   [dry-run] pyenv install %s && pyenv global %s\n' "$PY_VERSION" "$PY_VERSION"
elif command -v pyenv >/dev/null 2>&1; then
  if pyenv versions --bare | grep -qx "$PY_VERSION"; then
    ok "$PY_VERSION zaten kurulu"
  else
    pyenv install "$PY_VERSION" && pyenv global "$PY_VERSION"
  fi
else
  warn "pyenv yok, atlandi"
fi

# --- kapanis ------------------------------------------------------------
echo
ok "kurulum bitti"
cat <<'NEXT'

Elle tasinmasi gerekenler (bu repoda YOK, olmamali da):
  ~/.zshrc.local            kuruma ozel degiskenler
  ~/.p10k.zsh               prompt ayarlari (yoksa: p10k configure)
  ~/.ssh/                   anahtarlar, config, config.d/, scripts/
  ~/.gnupg/                 git imzalama anahtari
  ~/.kube/                  kubeconfig'ler + kubie.yaml (config bir DIZIN olmali)
  ~/.gitconfig              + ~/.gitconfig-github
  ~/.aws/ ~/.pgpass ~/.config/pgcreds/ ~/.config/cloudflare/
  ~/.local/bin/             cfro, fssh-tui, subctl (brew'de yok)

Sonra:
  exec zsh
  kubie ctx && gitp && k version --client     # uc kritik yol
NEXT

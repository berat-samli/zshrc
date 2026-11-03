# ============================================================================
# Powerlevel10k instant prompt — must stay near the top of ~/.zshrc.
# Code that needs console input (password prompts, [y/n]) goes ABOVE this.
# ============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================================
# Oh My Zsh
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)

[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# zsh-autosuggestions (brew)
[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# ============================================================================
# PATH
# ============================================================================
export PYENV_ROOT="$HOME/.pyenv"
export BUN_INSTALL="$HOME/.bun"

path=(
  "$HOME/.local/bin"
  "${KREW_ROOT:-$HOME/.krew}/bin"
  "$PYENV_ROOT/shims"
  "$PYENV_ROOT/bin"
  "$BUN_INSTALL/bin"
  "$HOME/flutter/bin"
  "$HOME/kind"
  "/opt/homebrew/opt/llvm@18/bin"
  "/opt/homebrew/opt/make/libexec/gnubin"
  "/opt/homebrew/opt/coreutils/libexec/gnubin"
  "/opt/homebrew/opt/helm@3/bin"
  "/opt/homebrew/opt/postgresql@18/bin"
  "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  $path
)
# drop non-existent entries and duplicates
typeset -gU path PATH
path=($^path(N-/))

# ============================================================================
# Environment
# ============================================================================
export GPG_TTY=$(tty)

command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ============================================================================
# Aliases — kubernetes
# ============================================================================
alias k='kubectl'
alias kget='kubectl get pods'
alias kevents='kubectl get events --all-namespaces --sort-by=.lastTimestamp'

# kubie (context/namespace switching)
alias kctx='kubie ctx'
alias kns='kubie ns'
alias kinfo='kubie info'
alias klist='kubie ctx'
alias kswitch='kubie ctx'

# ============================================================================
# Aliases — ansible
# ============================================================================
alias a='ansible'
alias ap='ansible-playbook'
alias ai='ansible-inventory'
alias ag='ansible-galaxy'
alias av='ansible-vault'

# ============================================================================
# Aliases — misc
# ============================================================================
alias python3='python3.12'
alias dockerinstall='print -r -- "curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh" | tee /dev/tty | pbcopy'

# ============================================================================
# SSH helpers (passwords live in ~/.ssh/scripts/, never in this file)
# ============================================================================
alias sshr='sshpass -f ~/.ssh/scripts/.oar ssh -l root'
alias sshb='sshpass -f ~/.ssh/scripts/.beratsamli ssh -l root'
alias sshe='sshpass -f ~/.ssh/scripts/.entra ssh -l "${ODEAL_AD_USER:?set ODEAL_AD_USER}"'
alias sshc='sshpass -f ~/.ssh/scripts/.com ssh -l "${ODEAL_MAIL_USER:?set ODEAL_MAIL_USER}"'

# ============================================================================
# Functions — git
# ============================================================================
gitp() {
    if [[ $1 != "-m" || -z $2 ]]; then
        echo "Kullanım: gitp -m \"commit mesajınız\""
        return 1
    fi

    local commit_message="$2"

    echo "🔄 Git pull yapılıyor..."
    git pull || { echo "❌ Git pull başarısız!"; return 1; }

    echo "🔄 Git add yapılıyor..."
    git add . || { echo "❌ Git add başarısız!"; return 1; }
    echo "✅ Git add tamamlandı"

    echo "🔄 Commit yapılıyor: $commit_message"
    git commit -m "$commit_message" || { echo "❌ Commit başarısız!"; return 1; }
    echo "✅ Commit tamamlandı"

    echo "🔄 Push yapılıyor..."
    git push || { echo "❌ Push başarısız!"; return 1; }
    echo "✅ Push tamamlandı! 🚀"
}

# ============================================================================
# Functions — network
# ============================================================================
flushdns() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
}

# ============================================================================
# Functions — kubernetes debug
# ============================================================================
K8S=/opt/homebrew/bin/kubectl
KUBECTX=/opt/homebrew/bin/kubectx

# netshoot ephemeral container: kdbn pod/<name>
kdbn() {
    echo "Starting NetShot Debugger ..."
    "$K8S" debug "$@" -ti --image=nicolaka/netshoot -- bash
}

# kdebugger <name> <image> <shell> [--node <node>] [kubectl args...]
kdebugger() {
    local name="$1";  shift
    local image="$1"; shift
    local shell="$1"; shift

    local ctx uniq_name node_name=""
    ctx=$("$KUBECTX" -c | sed 's/aks-bynr-//g')
    uniq_name="${ctx}-${name}-$(date +%s | shasum | base64 | head -c 4 | tr '[:upper:]' '[:lower:]')"

    if [[ "$1" == "--node" ]]; then
        shift
        node_name="$1"
        shift
    fi

    echo "Ephemeral container is starting ... ( $uniq_name / $image / $shell ON $ctx )"

    if [[ -n "$node_name" ]]; then
        echo "Targeting node: $node_name"
        "$K8S" run -ti --rm "$uniq_name" --image="$image" \
            --overrides="{\"spec\":{\"nodeName\":\"$node_name\"}}" \
            "$@" -- "$shell"
    else
        "$K8S" run -ti --rm "$uniq_name" --image="$image" "$@" -- "$shell"
    fi
}

# ksh <pod> [kubectl args...]
ksh() {
    "$K8S" exec -ti "$@" -- sh
}

alias kd='kdebugger debugger "docker.io/msenturk/alpine-debug:v1" bash'
alias kdba='kdebugger alpine-debugger "alpine:latest" sh'
alias kdbc='kdebugger curl-debugger "curlimages/curl:latest" sh'
alias kdbd='kdebugger debian-debugger "debian:bookworm" bash'
alias kdbu='kdebugger ubuntu-debugger "ubuntu:latest" bash'
alias kdbr='kdebugger redis-debugger "redis:latest" bash'
alias kdbm='kdebugger mongo-debugger "mongo:latest" bash'
alias kdbp='kdebugger psql-debugger "postgres:bookworm" bash'
alias kdbnetcore='kdebugger dotnet-debugger "mcr.microsoft.com/dotnet/sdk:8.0" bash'

# ============================================================================
# Functions — kubernetes secrets
# ============================================================================
# YAML secret data değerlerini base64'e encode eder (dosyayı yerinde değiştirir)
encode_secret() {
  local file="$1"

  if [[ -z "$file" ]]; then
    echo "Kullanım: encode_secret <dosya.yaml>" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "Hata: '$file' bulunamadı" >&2
    return 1
  fi

  local in_data=false output="" line indent key value encoded

  while IFS= read -r line; do
    if [[ "$line" =~ '^[[:space:]]*data[[:space:]]*:' ]]; then
      in_data=true
      output+="${line}"$'\n'
      continue
    fi

    if $in_data && [[ "$line" =~ '^[[:space:]]+[^[:space:]]+:[[:space:]]+[^[:space:]]' ]]; then
      indent="${line%%[^[:space:]]*}"
      key="${${line#"$indent"}%%:*}"
      value="${${line#*:}# }"
      encoded=$(printf '%s' "$value" | base64)
      output+="${indent}${key}: ${encoded}"$'\n'
      continue
    fi

    [[ "$line" =~ '^[^[:space:]]' ]] && in_data=false

    output+="${line}"$'\n'
  done < "$file"

  printf '%s' "$output" > "$file"
  cat "$file"
}

# YAML secret data değerlerini base64'ten decode eder (dosyayı yerinde değiştirir)
decode_secret() {
  local file="$1"

  if [[ -z "$file" ]]; then
    echo "Kullanım: decode_secret <dosya.yaml>" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "Hata: '$file' bulunamadı" >&2
    return 1
  fi

  local in_data=false output="" line indent key value decoded

  while IFS= read -r line; do
    if [[ "$line" =~ '^[[:space:]]*data[[:space:]]*:' ]]; then
      in_data=true
      output+="${line}"$'\n'
      continue
    fi

    if $in_data && [[ "$line" =~ '^[[:space:]]+[^[:space:]]+:[[:space:]]+[^[:space:]]' ]]; then
      indent="${line%%[^[:space:]]*}"
      key="${${line#"$indent"}%%:*}"
      value="${${line#*:}# }"

      if decoded=$(printf '%s' "$value" | base64 --decode 2>/dev/null); then
        output+="${indent}${key}: ${decoded}"$'\n'
      else
        echo "Uyarı: '$key' decode edilemedi, orijinal bırakıldı" >&2
        output+="${line}"$'\n'
      fi
      continue
    fi

    [[ "$line" =~ '^[^[:space:]]' ]] && in_data=false

    output+="${line}"$'\n'
  done < "$file"

  printf '%s' "$output" > "$file"
  cat "$file"
}

# ksecdump <secret-adi> [namespace]
ksecdump() {
    if [[ -z "$1" ]]; then
        echo "Kullanım: ksecdump <secret-adi> [namespace]" >&2
        return 1
    fi

    local ns="$2"
    if [[ -z "$ns" ]]; then
        ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
        [[ -z "$ns" ]] && ns="default"
    fi

    kubectl get secret "$1" -n "$ns" -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
}

# external-secrets: force-sync anotasyonu bas
kannoes() {
    if [[ -z "$1" ]]; then
        echo "Kullanım: kannoes <secret-adi> [kubectl-args...]" >&2
        return 1
    fi
    local secret="$1"; shift
    kubectl annotate es "$secret" force-sync="$(date +%s)" --overwrite "$@"
}

# ============================================================================
# Functions — SSH inventory (fssh)
# ============================================================================
: "${INVENTORY_IMAGE:=harbor.example.com/devops/inventory:v0.1.0}"

_fssh_update() {
    local tmp
    tmp=$(mktemp -d) || return 1

    {
        docker run --rm -t                                \
            --entrypoint=""                               \
            --platform=linux/amd64                        \
            -v ~/.ssh/.scripts/.env:/app/.env             \
            -v ~/.ssh/.scripts/config.yml:/app/config.yml \
            -v "$tmp":/app/output                         \
        "$INVENTORY_IMAGE" go-task inventory
    } && {
        ansible-inventory -i "$tmp/inventory.yml" --list --limit 'os_linux' | \
            jq -r '._meta.hostvars | to_entries[] | "Host \(.key)\n  Hostname \(.value.ansible_host // .key)\n  User root"' > \
                ~/.ssh/config.d/vmware.conf
    } || echo "SSH update failed!" >&2

    rm -rf "$tmp"
}

fssh() {
    local host
    host=$(fssh-tui) && [[ -n "$host" ]] && sshpass -f ~/.ssh/scripts/.oar ssh -l root "$host"
}

# ============================================================================
# Completions / prompt (keep at the end)
# ============================================================================
# bun
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Makineye özel / gizli ayarlar (git'e girmez)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

#!/bin/bash
# =============================================================================
# bootstrap-ccweb.sh -- Bootstrap CCWeb (Codespace/container Linux ephemere)
# =============================================================================
# S136a-ccdd, IDEE_infra_149 Etape 8.
#
# BUT : dans un container ephemere CCWeb (Codespace GitHub, session Claude Code
# Web, VPS distant), installer age + bw + dechiffrer secrets.env pour utilisation
# en session, sans coller de secret dans le chat.
#
# PREREQUIS :
# - Container Linux (Debian/Ubuntu/Alpine) avec sudo + npm + curl + jq
# - Compte Bitwarden actif de David (email + master password + 2FA)
# - Note Bitwarden "age keys.txt dr-secrets" avec les 3 lignes reelles de keys.txt
#   (validee bout en bout S136a-ccdd, Test B PARITE OK)
# - Repo dr-secrets accessible via https (clone public/prive avec GitHub token)
#
# USAGE (dans un container CCWeb) :
#   curl -sSL https://raw.githubusercontent.com/DevDaveRug/dr-secrets/main/scripts/bootstrap-ccweb.sh | bash
#
# ou :
#   git clone https://github.com/DevDaveRug/dr-secrets.git /tmp/dr-secrets
#   bash /tmp/dr-secrets/scripts/bootstrap-ccweb.sh
#
# SORTIE :
# - age installe dans /usr/local/bin/age
# - bw installe globalement via npm
# - ~/.config/age/keys.txt cree avec ACL 600
# - ~/.cc-secrets/secrets.env cree avec ACL 600 (ephemere, disparait avec le container)
# =============================================================================

set -euo pipefail

AGE_VERSION="v1.3.1"
DR_SECRETS_REPO="https://github.com/DevDaveRug/dr-secrets.git"
DR_SECRETS_LOCAL="${HOME}/dr-secrets"
BW_ITEM_NAME="age keys.txt dr-secrets"

echo "=== bootstrap-ccweb.sh (S136a-ccdd, IDEE_infra_149) ==="
echo ""

# ---- 1. Verifier les prerequis systeme ----
echo "-> 1. Verification prerequis"
for cmd in curl jq npm; do
  if ! command -v "$cmd" >/dev/null; then
    echo "   ERREUR : $cmd manquant. Installe-le d abord (apt install $cmd)."
    exit 1
  fi
done
echo "   curl, jq, npm : OK"
echo ""

# ---- 2. Installer age ----
if ! command -v age >/dev/null; then
  echo "-> 2. Installation age ${AGE_VERSION}"
  curl -sSLo /tmp/age.tgz "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz"
  tar -xzf /tmp/age.tgz -C /tmp
  sudo mv /tmp/age/age /tmp/age/age-keygen /usr/local/bin/
  sudo chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
  rm -rf /tmp/age.tgz /tmp/age
  echo "   age installe : $(age --version 2>&1)"
else
  echo "-> 2. age deja present : $(age --version 2>&1)"
fi
echo ""

# ---- 3. Installer Bitwarden CLI ----
if ! command -v bw >/dev/null; then
  echo "-> 3. Installation Bitwarden CLI (via npm)"
  sudo npm install -g @bitwarden/cli
  echo "   bw installe : $(bw --version 2>&1)"
else
  echo "-> 3. bw deja present : $(bw --version 2>&1)"
fi
echo ""

# ---- 4. bw login + unlock interactif ----
echo "-> 4. Session Bitwarden"
STATUS=$(bw status | jq -r .status)
echo "   status = $STATUS"

if [ "$STATUS" = "unauthenticated" ]; then
  echo "   -> bw login requis. Tape ton email + master password + 2FA :"
  bw login
  STATUS=$(bw status | jq -r .status)
fi

if [ "$STATUS" = "locked" ] || [ -z "${BW_SESSION:-}" ]; then
  echo "   -> vault verrouille, unlock (tape master password) :"
  export BW_SESSION=$(bw unlock --raw)
  if [ -z "$BW_SESSION" ]; then
    echo "   ERREUR : bw unlock a echoue."
    exit 1
  fi
  echo "   BW_SESSION exporte."
fi
echo ""

# ---- 5. Recuperer keys.txt depuis Bitwarden ----
echo "-> 5. Recuperation age keys.txt depuis Bitwarden"
mkdir -p "${HOME}/.config/age"
bw get notes "$BW_ITEM_NAME" --session "$BW_SESSION" > "${HOME}/.config/age/keys.txt"
chmod 600 "${HOME}/.config/age/keys.txt"

if ! grep -q "AGE-SECRET-KEY-" "${HOME}/.config/age/keys.txt"; then
  echo "   ERREUR : la note BW ne contient pas AGE-SECRET-KEY-. Verifie la note '$BW_ITEM_NAME' dans ton vault."
  exit 1
fi
echo "   keys.txt recupere ($(wc -l < ${HOME}/.config/age/keys.txt) lignes) et proteges ACL 600"
echo ""

# ---- 6. Cloner dr-secrets si absent ----
if [ ! -d "$DR_SECRETS_LOCAL" ]; then
  echo "-> 6. Clone dr-secrets"
  git clone "$DR_SECRETS_REPO" "$DR_SECRETS_LOCAL"
else
  echo "-> 6. dr-secrets deja present, git pull"
  (cd "$DR_SECRETS_LOCAL" && git pull --ff-only)
fi
echo ""

# ---- 7. Decrypter secrets.env ----
echo "-> 7. Decrypt secrets.env.age -> ~/.cc-secrets/secrets.env"
mkdir -p "${HOME}/.cc-secrets"
age -d -i "${HOME}/.config/age/keys.txt" "${DR_SECRETS_LOCAL}/secrets.env.age" > "${HOME}/.cc-secrets/secrets.env"
chmod 600 "${HOME}/.cc-secrets/secrets.env"
echo "   secrets.env decrypte ($(wc -l < ${HOME}/.cc-secrets/secrets.env) lignes) et proteges ACL 600"
echo ""

# ---- 8. Rapport final ----
echo "=== FIN bootstrap-ccweb ==="
echo "Val : age installe dans /usr/local/bin/age"
echo "Val : bw installe et session unlocked"
echo "Val : ~/.config/age/keys.txt cree (ACL 600)"
echo "Val : ~/.cc-secrets/secrets.env decrypte (ACL 600)"
echo ""
echo "Container ephemere : ~/.cc-secrets/secrets.env disparait avec le container."
echo "Rappel : ne JAMAIS commit ce fichier, ne JAMAIS le copier dans un repo git."
echo ""
echo "Pour utiliser dans Claude Code :"
echo "  export BW_SESSION='$BW_SESSION'  # (si besoin dans une sous-shell)"
echo "  cat ~/.cc-secrets/secrets.env   # verifier les secrets disponibles"

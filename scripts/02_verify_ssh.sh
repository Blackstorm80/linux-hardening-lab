#!/usr/bin/env bash
#
# Couche 2 — Contrôle du durcissement SSH
#
# Miroir de conf/sshd_hardening.conf : chaque directive déclarée, ce script
# la vérifie. Lecture seule, sort en 1 si une directive a dérivé.
#
# POINT CLÉ — où lit-on l'état ?
#   PAS dans le fichier de config (il dirait seulement « ce qu'on a écrit »).
#   On interroge « sshd -T » : la configuration EFFECTIVE que le démon applique
#   réellement, après fusion de tous les includes et de ses valeurs par défaut.
#   Un contrôle interroge la réalité, pas l'intention.
#   ( -T majuscule = dump de la config effective ; -t minuscule = test syntaxe )
#
# Usage :  sudo ./02_verify_ssh.sh     (sshd -T exige les droits root)

set -uo pipefail

ECHECS=0

# On capture l'état effectif UNE fois. sshd -T échoue si la config est invalide
# ou si /run/sshd manque : on le signale clairement plutôt que de deviner.
ETAT="$(sshd -T 2>/dev/null)" || {
  echo "Impossible de lire la configuration effective (sshd -T)." >&2
  echo "Causes probables : pas lancé en root, config invalide, ou /run/sshd absent." >&2
  exit 2
}

# sshd -T sort les clés EN MINUSCULES : « passwordauthentication no ».
# On compare donc en minuscules.
verifier() {
  local libelle="$1" cle="$2" attendu="$3"
  local obtenu
  obtenu="$(printf '%s\n' "$ETAT" | awk -v k="${cle,,}" 'tolower($1)==k {print $2; exit}')"
  if [[ "${obtenu,,}" == "${attendu,,}" ]]; then
    printf '  [ OK ]  %-38s %s\n' "$libelle" "$obtenu"
  else
    printf '  [FAIL]  %-38s attendu: %-6s obtenu: %s\n' "$libelle" "$attendu" "${obtenu:-absent}"
    ECHECS=$((ECHECS + 1))
  fi
}

echo "== Couche 2 : contrôle du durcissement SSH (sshd -T) =="
verifier "mot de passe interdit"        PasswordAuthentication no
verifier "connexion root directe interdite" PermitRootLogin       no
verifier "authentification par clé"     PubkeyAuthentication  yes

echo
if [[ $ECHECS -eq 0 ]]; then
  echo "SSH conforme au durcissement. (0 écart)"
  exit 0
else
  echo "DURCISSEMENT SSH DÉGRADÉ : $ECHECS écart(s)."
  echo "Réappliquer conf/sshd_hardening.conf dans /etc/ssh/sshd_config.d/, puis recharger sshd."
  exit 1
fi

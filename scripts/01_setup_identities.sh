#!/usr/bin/env bash
#
# Couche 1 — Identités et permissions
#
# Met en place la matrice d'accès du répertoire protégé :
#   - un groupe de sécurité          : audit_team
#   - un utilisateur restreint       : inspecteur, membre du groupe
#   - un répertoire protégé          : /opt/donnees_sensibles
#   - la matrice                     : root:audit_team, droits 750
#
# IDEMPOTENT : relançable autant de fois que voulu, sans erreur et sans
# modifier l'état s'il est déjà correct.
#
# Usage :  sudo ./01_setup_identities.sh

set -euo pipefail

GROUPE="audit_team"
UTILISATEUR="inspecteur"
REPERTOIRE="/opt/donnees_sensibles"
DROITS="750"

# set -u traite une variable non définie comme une erreur : sans ce garde-fou,
# une faute de frappe dans $REPERTOIRE ferait travailler le script sur "/".
[[ -n "$REPERTOIRE" && "$REPERTOIRE" != "/" ]] || { echo "REPERTOIRE invalide" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé en root (sudo)." >&2
  exit 1
fi

echo "== Couche 1 : mise en place de la matrice d'identités =="

# 1. Le groupe de sécurité.
#    `groupadd -f` ne fait rien si le groupe existe déjà, au lieu d'échouer :
#    c'est l'idempotence offerte par l'outil lui-même.
groupadd -f "$GROUPE"
echo "  groupe $GROUPE ....... présent"

# 2. L'utilisateur restreint.
#    `useradd` n'a pas d'équivalent de -f : on teste avant d'agir.
if id -u "$UTILISATEUR" >/dev/null 2>&1; then
  echo "  utilisateur $UTILISATEUR .. déjà présent"
else
  useradd --create-home --shell /bin/bash "$UTILISATEUR"
  echo "  utilisateur $UTILISATEUR .. créé"
fi

# 3. L'appartenance au groupe.
#    -a (append) est essentiel : sans lui, usermod -G REMPLACE la liste des
#    groupes secondaires et retirerait l'utilisateur de tous les autres.
usermod -aG "$GROUPE" "$UTILISATEUR"
echo "  $UTILISATEUR membre de $GROUPE"

# 4. Le répertoire protégé. `mkdir -p` est idempotent par construction.
mkdir -p "$REPERTOIRE"

# 5. La matrice d'accès.
#    Les deux lignes suivantes sont inséparables, et c'est la leçon de
#    l'incident 01 : des droits 750 sur un mauvais groupe propriétaire ne
#    protègent rien — l'utilisateur bascule dans la catégorie « autres ».
chown root:"$GROUPE" "$REPERTOIRE"
chmod "$DROITS" "$REPERTOIRE"

echo "  $REPERTOIRE ........... root:$GROUPE $DROITS"
echo
echo "État final :"
ls -ld "$REPERTOIRE"
echo
echo "Terminé. Contrôler avec : ./01_verify_identities.sh"

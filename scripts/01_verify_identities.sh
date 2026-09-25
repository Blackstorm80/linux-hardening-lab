#!/usr/bin/env bash
#
# Couche 1 — Contrôle de la matrice d'identités
#
# Miroir de 01_setup_identities.sh : chaque chose que le setup AFFIRME,
# ce script la VÉRIFIE.
#
# Sort en 0 si tout est conforme, en 1 si la matrice a dérivé.
# Ce code de sortie est le point important : il permet de brancher ce
# contrôle dans une tâche planifiée ou une chaîne d'intégration.
#
# Usage :  ./01_verify_identities.sh

# Volontairement PAS de `set -e` ici.
# Un script de contrôle doit signaler TOUTES les dérives, pas s'arrêter
# à la première. On collecte, puis on rend un verdict global.
set -uo pipefail

GROUPE="audit_team"
UTILISATEUR="inspecteur"
REPERTOIRE="/opt/donnees_sensibles"
PROPRIETAIRE_ATTENDU="root"
DROITS_ATTENDUS="750"

ECHECS=0

# Compare une valeur attendue à la valeur observée et tranche.
verifier() {
  local libelle="$1" attendu="$2" obtenu="$3"
  if [[ "$attendu" == "$obtenu" ]]; then
    printf '  [ OK ]  %-38s %s\n' "$libelle" "$obtenu"
  else
    printf '  [FAIL]  %-38s attendu: %-14s obtenu: %s\n' "$libelle" "$attendu" "$obtenu"
    ECHECS=$((ECHECS + 1))
  fi
}

echo "== Couche 1 : contrôle de la matrice d'identités =="

# 1. Le groupe de sécurité existe-t-il ?
if getent group "$GROUPE" >/dev/null; then
  verifier "groupe $GROUPE" "présent" "présent"
else
  verifier "groupe $GROUPE" "présent" "ABSENT"
fi

# 2. L'utilisateur restreint existe-t-il ?
if id -u "$UTILISATEUR" >/dev/null 2>&1; then
  verifier "utilisateur $UTILISATEUR" "présent" "présent"
else
  verifier "utilisateur $UTILISATEUR" "présent" "ABSENT"
fi

# 3. L'utilisateur est-il membre du groupe ?
if id -nG "$UTILISATEUR" 2>/dev/null | tr ' ' '\n' | grep -qx "$GROUPE"; then
  verifier "$UTILISATEUR membre de $GROUPE" "oui" "oui"
else
  verifier "$UTILISATEUR membre de $GROUPE" "oui" "NON"
fi

# 4. Le répertoire protégé existe-t-il ?
if [[ -d "$REPERTOIRE" ]]; then
  verifier "répertoire $REPERTOIRE" "présent" "présent"

  # 5a. Le propriétaire est-il le bon ?
  verifier "propriétaire" "$PROPRIETAIRE_ATTENDU" "$(stat -c '%U' "$REPERTOIRE")"

  # 5b. LE GROUPE PROPRIÉTAIRE est-il le bon ?
  #     C'est CE contrôle qui aurait détecté l'incident 01 : les droits
  #     octaux étaient restés à 750, seul le groupe avait dérivé vers root,
  #     ce qui faisait basculer l'utilisateur dans la catégorie « autres ».
  verifier "groupe propriétaire" "$GROUPE" "$(stat -c '%G' "$REPERTOIRE")"

  # 5c. Les droits octaux sont-ils les bons ?
  #     Insuffisant seul — mais indispensable : c'est le seul contrôle qui
  #     verrait quelqu'un passer le répertoire en 777.
  verifier "droits octaux" "$DROITS_ATTENDUS" "$(stat -c '%a' "$REPERTOIRE")"
else
  verifier "répertoire $REPERTOIRE" "présent" "ABSENT"
fi

echo
if [[ $ECHECS -eq 0 ]]; then
  echo "Matrice conforme. (0 écart)"
  exit 0
else
  # Verdict sur stdout, et non sur stderr.
  #
  # stderr n'est pas tamponné alors que stdout l'est par blocs dès que la
  # sortie part dans un tuyau ou un fichier : le verdict doublerait les
  # résultats et s'afficherait AVANT eux dans les journaux.
  # Le signal lisible par une machine, c'est le code de sortie — pas le flux.
  echo "MATRICE DÉGRADÉE : $ECHECS écart(s) détecté(s)."
  echo "Réparer avec : sudo ./01_setup_identities.sh"
  exit 1
fi

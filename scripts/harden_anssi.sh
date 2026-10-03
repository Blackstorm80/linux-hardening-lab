#!/usr/bin/env bash
#
# Durcissement ANSSI — applique les recommandations sysctl de ANSSI-BP-028.
#
# Pendant « setup » de audit_anssi.sh :
#   audit_anssi.sh  LIT  et signale les écarts.
#   harden_anssi.sh ÉCRIT et les corrige.
#
# IDEMPOTENT : installe un fichier de configuration à contenu fixe, puis
# l'applique. Relançable sans effet de bord.
#
# Forme correcte, et c'est le point : on n'utilise PAS `sysctl -w` (qui ne
# survit pas au redémarrage). On dépose un fichier dans /etc/sysctl.d/ —
# persistant — puis on le charge. Durcir sans persister, c'est durcir jusqu'au
# prochain reboot seulement.
#
# Usage :  sudo ./harden_anssi.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé en root (sudo)." >&2
  exit 1
fi

# Le fichier de référence vit dans conf/, à côté de scripts/.
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$ICI/../conf/99-anssi-hardening.conf"
CIBLE="/etc/sysctl.d/99-anssi-hardening.conf"

[[ -f "$SOURCE" ]] || { echo "Fichier de référence introuvable : $SOURCE" >&2; exit 1; }

echo "== Durcissement ANSSI (sysctl) =="

# 1. Installer la configuration persistante.
install -m 0644 "$SOURCE" "$CIBLE"
echo "  configuration installée : $CIBLE"

# 2. L'appliquer immédiatement.
#    Piège : `sysctl -p` sort en 0 MÊME quand des clés sont refusées (il les
#    « ignore » en affichant un avertissement). On ne peut donc pas se fier à
#    son code de sortie — il faut lire sa sortie et compter les refus, sinon
#    le script mentirait en annonçant « appliqué » alors que rien ne l'a été.
SORTIE_APPLY="$(sysctl -p "$CIBLE" 2>&1 || true)"
REFUS="$(printf '%s\n' "$SORTIE_APPLY" | grep -c -i 'read-only\|ignoring' || true)"

if [[ "$REFUS" -eq 0 ]]; then
  echo "  configuration appliquée au noyau courant"
else
  echo "  ⚠ $REFUS clé(s) REFUSÉE(S) : /proc/sys est monté en lecture seule ici."
  echo "    → C'est le cas dans un conteneur non privilégié : il partage le noyau"
  echo "      de l'hôte et n'a pas le droit de le reconfigurer. Ce n'est pas un bug,"
  echo "      c'est une protection du conteneur."
  echo "    → Le fichier $CIBLE est néanmoins en place et s'appliquerait AU DÉMARRAGE"
  echo "      sur une vraie machine ou une VM. Ici, ni applicable ni démontrable."
  echo "    → Voir docs/incident_02_sysctl_readonly.md"
fi

# 3. umask (R35) : ce n'est pas un sysctl. Valeur fixée pour les futurs
#    shells de connexion via /etc/profile.d. N'affecte PAS le shell courant.
UMASK_FILE="/etc/profile.d/99-anssi-umask.sh"
printf '# ANSSI R35 — umask restrictif\numask 027\n' > "$UMASK_FILE"
chmod 0644 "$UMASK_FILE"
echo "  umask 027 déposé dans $UMASK_FILE (effectif aux prochaines connexions)"

echo
echo "Terminé. Contrôler avec : ./audit_anssi.sh"

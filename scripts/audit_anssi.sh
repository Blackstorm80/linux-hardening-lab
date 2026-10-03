#!/usr/bin/env bash
#
# Audit ANSSI — application automatisée du guide ANSSI-BP-028
# « Recommandations de sécurité relatives à un système GNU/Linux »
#
# Script transversal (il ne dépend d'aucune couche en particulier) et
# STRICTEMENT EN LECTURE : il ne modifie jamais le système, il l'ausculte.
#
# Trois verdicts par contrôle :
#   [CONFORME]        la valeur observée respecte la recommandation
#   [ÉCART]           la valeur observée s'en écarte            → à corriger
#   [N/A conteneur]   la recommandation ne s'applique pas ici   → ni l'un ni l'autre
#
# Le code de sortie ne compte QUE les écarts réels : une recommandation
# non applicable dans un conteneur n'est pas un échec, et ne doit pas en
# devenir un. C'est la différence entre un audit honnête et un script qui
# coche des cases.
#
# Référence : ANSSI-BP-028, disponible publiquement sur cyber.gouv.fr.
# Les identifiants Rxx renvoient aux recommandations du guide.
#
# Usage :  ./audit_anssi.sh

set -uo pipefail   # PAS de -e : un audit signale TOUS les écarts, il ne s'arrête pas au premier.

ECARTS=0
NA=0

# --- helpers ---------------------------------------------------------------

# Compare une valeur sysctl observée à la valeur recommandée.
#   ctl  <clé sysctl>  <valeur attendue>  <id ANSSI>  <libellé>
ctl() {
  local cle="$1" attendu="$2" ref="$3" libelle="$4"
  local obtenu
  obtenu="$(sysctl -n "$cle" 2>/dev/null)"
  if [[ -z "$obtenu" ]]; then
    printf '  [N/A conteneur]  %-10s %-46s (clé absente)\n' "$ref" "$libelle"
    NA=$((NA + 1))
  elif [[ "$obtenu" == "$attendu" ]]; then
    printf '  [CONFORME]       %-10s %-46s %s\n' "$ref" "$libelle" "$obtenu"
  else
    printf '  [ÉCART]          %-10s %-46s attendu %s, obtenu %s\n' "$ref" "$libelle" "$attendu" "$obtenu"
    ECARTS=$((ECARTS + 1))
  fi
}

# Contrôle manuel : surface une information que l'humain doit juger.
#   info  <id ANSSI>  <libellé>  <valeur>
info() {
  printf '  [À REVOIR]       %-10s %-46s %s\n' "$1" "$2" "$3"
}

titre() { printf '\n— %s —\n' "$1"; }

echo "===== Audit ANSSI-BP-028 (lecture seule) ====="

# --- 1. Durcissement du noyau (R8, R9, R11, R14…) --------------------------
titre "Noyau"
ctl kernel.randomize_va_space 2 "R14"  "ASLR activé (espace mémoire aléatoire)"
ctl kernel.dmesg_restrict     1 "R6"   "journal noyau restreint (dmesg)"
ctl kernel.kptr_restrict      2 "R9"   "adresses noyau masquées"
ctl kernel.sysrq              0 "R11"  "touches magiques SysRq désactivées"
ctl fs.suid_dumpable          0 "R5"   "pas de core dump pour binaires SUID"
ctl fs.protected_symlinks     1 "R12"  "liens symboliques protégés"
ctl fs.protected_hardlinks    1 "R12"  "liens matériels protégés"

# --- 2. Durcissement réseau (R5x pile IPv4) --------------------------------
titre "Réseau (pile IPv4)"
ctl net.ipv4.ip_forward                  0 "R52" "routage désactivé (hors routeur)"
ctl net.ipv4.conf.all.accept_redirects   0 "R53" "redirections ICMP refusées"
ctl net.ipv4.conf.all.send_redirects     0 "R53" "pas d'émission de redirections"
ctl net.ipv4.conf.all.accept_source_route 0 "R54" "routage par la source refusé"
ctl net.ipv4.conf.all.rp_filter          1 "R56" "filtrage par chemin inverse (anti-spoofing)"
ctl net.ipv4.conf.all.log_martians       1 "R55" "journalisation des paquets illégitimes"
ctl net.ipv4.tcp_syncookies              1 "R57" "protection SYN flood (SYN cookies)"
ctl net.ipv4.icmp_echo_ignore_broadcasts 1 "R58" "ICMP broadcast ignoré (anti-amplification)"

# --- 3. Système de fichiers (R28, R50…) ------------------------------------
titre "Système de fichiers"

# Fichiers accessibles en écriture à tous SANS sticky bit : vecteur d'altération.
WW=$(find / -xdev -type f -perm -0002 2>/dev/null | grep -Ev '^/(proc|sys)' | wc -l)
if [[ "$WW" -eq 0 ]]; then
  printf '  [CONFORME]       %-10s %-46s %s\n' "R50" "aucun fichier world-writable" "0"
else
  printf '  [ÉCART]          %-10s %-46s %s fichier(s)\n' "R50" "fichiers world-writable détectés" "$WW"
  find / -xdev -type f -perm -0002 2>/dev/null | grep -Ev '^/(proc|sys)' | sed 's/^/      → /' | head -10
  ECARTS=$((ECARTS + 1))
fi

# Inventaire SUID/SGID : l'audit LISTE, l'humain décide ce qui est superflu (R28).
SUID=$(find / -xdev -type f -perm -4000 2>/dev/null | wc -l)
SGID=$(find / -xdev -type f -perm -2000 2>/dev/null | wc -l)
info "R28" "binaires SUID à passer en revue"  "$SUID trouvé(s)"
info "R28" "binaires SGID à passer en revue"  "$SGID trouvé(s)"

# umask : 027 recommandé (rien pour les « autres »).
UMASK=$(umask)
if [[ "$UMASK" == "0027" || "$UMASK" == "027" ]]; then
  printf '  [CONFORME]       %-10s %-46s %s\n' "R35" "umask restrictif" "$UMASK"
else
  printf '  [ÉCART]          %-10s %-46s attendu 0027, obtenu %s\n' "R35" "umask trop permissif" "$UMASK"
  ECARTS=$((ECARTS + 1))
fi

# --- 4. Recommandations hors périmètre conteneur ---------------------------
# On ne les teste PAS (elles échoueraient pour une mauvaise raison), mais on
# les NOMME : un lecteur doit savoir qu'elles existent et pourquoi elles
# ne sont pas évaluables ici.
titre "Hors périmètre d'un conteneur (non évalué)"
echo "  [N/A conteneur]  R1–R4      Mot de passe GRUB, chiffrement du disque, UEFI Secure Boot"
echo "  [N/A conteneur]  R8         Partitions séparées montées en nosuid / nodev / noexec"
echo "  [N/A conteneur]  R59        Pare-feu local (traité en couche 3, pas ici)"
NA=$((NA + 3))

# --- Verdict ---------------------------------------------------------------
echo
echo "Récapitulatif : $ECARTS écart(s) · $NA recommandation(s) non applicable(s) en conteneur."
if [[ "$ECARTS" -eq 0 ]]; then
  echo "Aucun écart sur les recommandations évaluables."
  exit 0
else
  echo "Des écarts subsistent. Les lignes [À REVOIR] demandent un jugement humain, pas une correction automatique."
  exit 1
fi

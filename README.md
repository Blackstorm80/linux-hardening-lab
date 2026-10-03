# Linux Hardening Lab

Laboratoire de durcissement d'un système Linux, construit **couche par couche** selon le
principe de défense en profondeur.

> **État au 25/09/2026 : couche 1 automatisée et contrôlée. 4 couches restantes.** Ce dépôt décrit ce qu'il contient,
> pas ce qu'il vise. Les couches non faites sont marquées comme telles.

---

## État d'avancement

| | Couche | État | Ce qui existe dans ce dépôt |
|---|---|---|---|
| 1 | **Identités et permissions** — utilisateurs, groupes, matrice octale | ✅ **faite** | 2 scripts idempotents + 1 rapport d'incident |
| 2 | **Accès** — durcissement SSH, authentification par clés | ⬜ non commencée | — |
| 3 | **Périmètre** — pare-feu en *default deny* | ⬜ non commencée | — |
| 4 | **Surveillance** — détection d'intrusion et traçabilité | ⬜ non commencée | — |
| 5 | **Isolation** — cloisonnement des services | ⬜ non commencée | — |

En complément des couches, un **audit transversal ANSSI** (voir plus bas) applique le
référentiel ANSSI-BP-028 à l'ensemble du système.

Je préfère un dépôt qui dit vrai à un dépôt qui promet.

---

## Ce que ce dépôt contient réellement

### Deux scripts, couche 1

| Script | Rôle |
|---|---|
| [`scripts/01_setup_identities.sh`](scripts/01_setup_identities.sh) | Met en place la matrice : groupe `audit_team`, utilisateur restreint `inspecteur`, répertoire protégé en `root:audit_team 750`. **Idempotent** — relançable sans erreur et sans effet de bord |
| [`scripts/01_verify_identities.sh`](scripts/01_verify_identities.sh) | **Miroir du précédent** : vérifie les 7 assertions du setup et **sort en code 1** si la matrice a dérivé |

**Le second est le plus utile des deux.** Il détecte précisément la panne décrite ci-dessous
— celle où les droits octaux restent parfaitement corrects pendant que l'accès est cassé :

```
  [FAIL]  groupe propriétaire   attendu: audit_team   obtenu: root
  [ OK ]  droits octaux                               750
```

Un contrôle qui n'aurait vérifié que `chmod` aurait répondu « conforme ».

### Audit ANSSI transversal (ANSSI-BP-028)

| Fichier | Rôle |
|---|---|
| [`scripts/audit_anssi.sh`](scripts/audit_anssi.sh) | **Lecture seule.** Confronte le système au référentiel ANSSI : sysctl noyau et réseau, fichiers *world-writable*, inventaire SUID/SGID, umask. Chaque contrôle porte son n° de recommandation. Trois verdicts : `CONFORME` / `ÉCART` / `N/A conteneur` |
| [`scripts/harden_anssi.sh`](scripts/harden_anssi.sh) | **Son pendant « setup ».** Installe `conf/99-anssi-hardening.conf` dans `/etc/sysctl.d/` et fixe l'umask. Idempotent |
| [`conf/99-anssi-hardening.conf`](conf/99-anssi-hardening.conf) | La configuration sysctl de référence, une ligne par recommandation |

**Ce que l'audit démontre honnêtement dans un conteneur** : l'umask est corrigé (R35), mais
les réglages `sysctl` du noyau sont **refusés** — `/proc/sys` y est monté en lecture seule.
C'est une protection du conteneur, pas une panne, et c'est documenté dans
[`docs/incident_02_sysctl_readonly.md`](docs/incident_02_sysctl_readonly.md). L'audit continue
donc, à juste titre, de signaler ces écarts : **il ne ment pas sous prétexte qu'un script de
durcissement a prétendu réussir.**

### Un rapport d'incident sur la couche 1 : [`docs/incident_01_permissions.md`](docs/incident_01_permissions.md)

Un répertoire protégé en `750` pour le groupe `audit_team` devient subitement inaccessible
à un membre de ce groupe. Les droits octaux n'ont pourtant pas bougé.

Le rapport suit le cheminement complet : symptôme (`Permission denied`), diagnostic par
`ls -ld`, identification de la vraie cause — **le groupe propriétaire avait été réinitialisé
à `root`, faisant basculer l'utilisateur dans la catégorie « autres »** — puis résolution et
preuve de la résolution.

**La leçon, et c'est le cœur du travail :** les permissions octales ne valent que si la
matrice d'identité tient. Un `chmod` correct sur un `chown` erroné ne protège rien.

---

## La méthode

Chaque couche suit le même cycle, et **aucune couche n'est considérée comme faite tant que
le cycle n'est pas bouclé** :

```
Comprendre  →  Construire  →  Casser  →  Réparer
```

- **Comprendre** — le mécanisme, avant l'outil.
- **Construire** — un script idempotent, relançable sans casser l'état existant.
- **Casser** — provoquer volontairement la panne pour éprouver la configuration.
- **Réparer** — diagnostiquer à partir des traces, puis écrire le rapport.

➡️ **Un rapport d'incident par couche.** C'est ce qui distingue un lab d'un tutoriel
recopié : le tutoriel montre que ça marche, le rapport montre qu'on sait quoi faire quand
ça ne marche plus.

---

## Environnement

| | |
|---|---|
| Système | Linux (Debian / Ubuntu) |
| Exécution | **Conteneur Docker** nommé `linuxlab` |
| Automatisation | Bash |

⚠️ **Ce lab tourne dans un conteneur, pas dans une machine virtuelle.** C'est une limite
assumée, et elle a des conséquences réelles sur ce qui est démontrable : un conteneur
partage le noyau de l'hôte, donc les couches qui touchent au noyau — traçabilité de type
`auditd`, certains modules de sécurité — ne pourront pas être éprouvées de la même façon.
Ce point sera traité quand la couche concernée arrivera.

---

## Structure du dépôt

```
docs/      rapports d'incident (couche 1, et audit ANSSI sysctl)
scripts/   scripts Bash : couches numérotées + audit/harden ANSSI
conf/      fichiers de configuration de référence (99-anssi-hardening.conf)
```

## Utilisation

```bash
sudo ./scripts/01_setup_identities.sh     # met en place, relançable
./scripts/01_verify_identities.sh         # contrôle — code 0 si conforme, 1 sinon
```

---

## Prochaine étape

**Couche 2 — l'accès** : durcissement de SSH (authentification par clés, refus de
l'authentification par mot de passe, refus de la connexion directe en root), avec le
même couple setup / contrôle, et le rapport d'incident qui va avec.

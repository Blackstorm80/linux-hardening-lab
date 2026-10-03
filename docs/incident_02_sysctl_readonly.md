# Rapport d'incident 02 : impossible d'appliquer le durcissement sysctl dans le conteneur

## 1. Contexte
Après l'audit ANSSI (`audit_anssi.sh`), sept écarts étaient relevés, dont plusieurs
réglages `sysctl` du noyau et de la pile réseau (journal noyau restreint, masquage des
adresses noyau, filtrage par chemin inverse, etc.). Le script `harden_anssi.sh` a été
écrit pour les corriger de la bonne manière : déposer un fichier persistant dans
`/etc/sysctl.d/` puis l'appliquer avec `sysctl -p`.

## 2. L'incident
Un test préalable avait été fait pour vérifier que les clés étaient modifiables :
```
sysctl -w kernel.dmesg_restrict=<valeur actuelle>   → succès
```
Ce test a conclu, à tort, que toutes les clés étaient modifiables.

Au moment de l'application réelle, chaque clé a été refusée :
```
sysctl: setting key "kernel.dmesg_restrict", ignoring: Read-only file system
sysctl: setting key "net.ipv4.conf.all.rp_filter", ignoring: Read-only file system
… (14 clés, toutes refusées)
```

Deux surprises :
1. **Le test préalable était faux.** Réécrire une clé avec sa valeur **déjà en place**
   est un quasi-non-événement, que `procps` accepte sans toucher au système de fichiers.
   Il ne prouve donc **rien** sur la possibilité d'écrire réellement. *Un test mal conçu
   ment : il faut tester le cas qui change quelque chose, pas le cas neutre.*
2. **`sysctl -p` sort en code 0** même lorsqu'il refuse toutes les clés (il les « ignore »).
   Se fier à son code de sortie aurait fait annoncer « appliqué » alors que rien ne l'était.

## 3. Diagnostic
Examen du montage de `/proc/sys` :
```
$ grep " /proc/sys " /proc/mounts
proc /proc/sys proc ro,nosuid,nodev,noexec,relatime 0 0
```
**`/proc/sys` est monté en lecture seule (`ro`).**

C'est le comportement normal d'un conteneur non privilégié : il **partage le noyau de
l'hôte**, et Docker interdit à un conteneur ordinaire de reconfigurer ce noyau commun. Ce
n'est pas une panne — c'est une **mesure d'isolation** : si un conteneur pouvait modifier
`kernel.*` ou la pile réseau, il affecterait l'hôte et tous les autres conteneurs.

## 4. Résolution
Il n'y a rien à « réparer » : le refus est correct. La bonne réponse est de **reconnaître
la limite de l'environnement** et de l'écrire :

- Le fichier `/etc/sysctl.d/99-anssi-hardening.conf` **reste en place**. Sur une vraie
  machine ou une VM, il serait chargé au démarrage et le durcissement serait effectif.
- Dans ce conteneur, il est **ni applicable, ni démontrable**. L'audit continue donc,
  légitimement, de signaler ces écarts — et c'est la preuve qu'il ne ment pas.
- `harden_anssi.sh` a été corrigé pour **détecter les refus** (lecture de la sortie de
  `sysctl -p`, et non de son code retour) et l'annoncer clairement.

## 5. Leçon apprise
Trois, en réalité :
1. **Un conteneur n'est pas une machine pour durcir un noyau.** Les réglages `sysctl`
   globaux relèvent de l'hôte. Ce lab peut *écrire* la configuration conforme à l'ANSSI,
   mais ne peut *prouver* son application que sur un système disposant de son propre noyau.
2. **Un test doit éprouver le cas qui change l'état**, jamais le cas neutre. Vérifier une
   écriture en réécrivant la valeur courante donne un faux positif.
3. **Un code de sortie 0 ne vaut pas preuve de succès.** `sysctl -p` « réussit » en
   ignorant ce qu'il ne peut pas faire. Il faut lire ce qu'un outil *dit*, pas seulement
   ce qu'il *retourne*.

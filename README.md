# Linux Server Hardening et Isolation Lab

## Objectif du Projet
Ce projet est un laboratoire d'administration système et de cybersécurité démontrant l'implémentation du concept de **Défense en Profondeur** (Defense in Depth). 

L'objectif est de partir d'un système Ubuntu Server nu et de le durcir couche par couche, en suivant une architecture en "oignon" : de la gestion stricte des identités du noyau jusqu'à l'isolation applicative via conteneurisation.

## Technologies Utilisées
* **OS & Virtualisation :** Ubuntu Server, VMware
* **Automatisation :** Bash (Scripts d'Infrastructure as Code)
* **Sécurité & Accès :** SSH (clés cryptographiques), UFW (Pare-feu)
* **Audit & Prévention :** auditd, fail2ban
* **Isolation :** Docker

## Architecture en Couches (La Méthode de l'Oignon)
1. **Le Cœur :** Gestion des identités (Users/Groups) et matrice des permissions octales.
2. **L'Accès :** Sécurisation des flux d'administration (SSH).
3. **Le Périmètre :** Filtrage réseau strict (Default Deny via UFW).
4. **La Surveillance :** Prévention des intrusions (fail2ban) et traçabilité noyau (auditd).
5. **L'Isolation :** Conteneurisation des services (Docker).

## Structure du Dépôt
* `/scripts` : Contient les scripts Bash d'automatisation numérotés par ordre d'exécution.
* `/docs` : Contient les rapports "Post-Mortem" détaillant la méthode de diagnostic et de résolution d'incidents provoqués pour tester la robustesse du système.
* `/conf` : Fichiers de configuration de référence.

## Méthodologie d'Apprentissage
Chaque couche de ce laboratoire a été construite selon le cycle de validation : **Comprendre -> Construire -> Casser (Test de résistance) -> Réparer (Analyse des logs)**. Les rapports d'incidents dans le dossier `/docs` reflètent cette démarche de test empirique.

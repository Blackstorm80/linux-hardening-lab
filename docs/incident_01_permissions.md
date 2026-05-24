# Rapport d'Incident 01 : Perte d'accès au répertoire d'audit

## 1. Contexte et Configuration Initiale
Un répertoire critique `/opt/donnees_sensibles` a été créé pour stocker les données d'audit. La politique de sécurité exigeait que seul l'utilisateur `root` possède un contrôle total, tandis que les membres du groupe `audit_team` (dont l'utilisateur restreint `inspecteur`) ne devaient avoir qu'un droit de lecture et de traversée (droits octaux : 750).

## 2. L'Incident (Test de Résistance)
Pour valider l'étanchéité de la configuration, une modification non autorisée de la propriété du dossier a été simulée depuis le compte administrateur :
`sudo chown root:root /opt/donnees_sensibles`

## 3. Symptômes Observés
Lors de la tentative d'accès au dossier avec l'utilisateur `inspecteur` (qui appartient bien au groupe `audit_team`), le système a renvoyé l'erreur critique suivante :
`bash: cd: /opt/donnees_sensibles: Permission denied`

## 4. Investigation et Diagnostic
Pour comprendre pourquoi l'accès était refusé malgré des droits octaux inchangés (750), une analyse du conteneur a été effectuée avec la commande `ls -ld` :

Sortie de la commande `ls -ld /opt/donnees_sensibles` :
`drwxr-x--- 2 root root 4096 May 25 01:07 /opt/donnees_sensibles`

**Analyse :** * `r-x` : Les droits du groupe permettent bien la lecture et la traversée.
* `root root` : Le problème vient de la propriété. Le groupe propriétaire est redevenu `root` au lieu de `audit_team`. L'utilisateur `inspecteur` est donc relégué à la catégorie "autres" (les trois derniers tirets `---`), qui n'a aucun droit.

## 5. Résolution
Restauration de la propriété au groupe de sécurité correct depuis le compte administrateur :
`sudo chown root:audit_team /opt/donnees_sensibles`

Validation de la réparation (preuve de résolution) :
`drwxr-x--- 2 root audit_team 4096 May 25 01:15 /opt/donnees_sensibles`
L'utilisateur `inspecteur` a recouvré son accès en lecture seule.

## 6. Leçon Apprise
Cet incident démontre que les permissions octales (chmod) ne sont opérantes que si la matrice d'identité (chown/chgrp) est strictement maintenue. En sécurité, l'usurpation ou la modification accidentelle du groupe propriétaire neutralise instantanément les règles d'accès configurées.

# Rapport d'incident 03 : durcir SSH sans se verrouiller dehors

## 1. Contexte
Couche 2 : interdire l'authentification par mot de passe (`PasswordAuthentication no`)
et la connexion directe de root (`PermitRootLogin no`), ne garder que l'authentification
par clé. Trois directives, validées par `sshd -t`, vérifiées par `02_verify_ssh.sh`.

## 2. Le danger propre à cette couche
SSH n'est pas la couche 1. Une erreur de permissions sur un dossier se corrige depuis la
machine. **Mais couper sa propre voie d'accès à SSH, c'est se condamner à ne plus pouvoir
entrer** — sur un serveur distant, il n'y a pas de « retour en arrière » : plus de session.

Le scénario classique, et il arrive à tout le monde une fois :
```
1. sed -i 's/.../PasswordAuthentication no/' ...
2. systemctl restart sshd
3. (la session se ferme)
4. reconnexion refusee -- aucune cle n'avait ete deposee.
   Le mot de passe est desormais interdit : plus aucun moyen d'entrer.
```
On a coupe la seule methode qui marchait **avant** d'avoir rendu l'autre methode operationnelle.

## 3. L'ordre qui évite le verrouillage
Dans ce lab, l'ordre a été choisi pour que l'accès ne soit jamais perdu :
1. **Générer la clé**, puis **déposer la clé publique** chez l'utilisateur (`authorized_keys`).
2. **Tester que la clé fonctionne** — connexion réussie en tant qu'`inspecteur`.
3. **Seulement ensuite**, interdire le mot de passe.

La règle : **on n'enlève l'ancienne serrure qu'après avoir vérifié que la nouvelle clé ouvre.**
Sur un serveur distant, on ajoute une ceinture : **garder une seconde session ouverte**
pendant le changement, pour pouvoir réparer si la reconnexion échoue.

## 4. Test de résistance (ce qui a été provoqué)
Matrice de connexion, serveur durci :

| Tentative | Résultat | Preuve |
|---|---|---|
| `inspecteur` avec la clé | **acceptée** | `CONNECTE comme inspecteur` |
| `root` avec la même clé valide | **refusée** | `Permission denied (publickey)` — `PermitRootLogin no` bloque root même avec une clé correcte |
| `inspecteur` par mot de passe | **refusée** | `Permission denied (publickey)` — le serveur n'offre que `publickey` |

Puis dérive volontaire : `PermitRootLogin yes`, rechargement de sshd. Le contrôle
`02_verify_ssh.sh` l'a détectée :
```
[FAIL]  connexion root directe interdite    attendu: no   obtenu: yes
DURCISSEMENT SSH DEGRADE : 1 ecart(s).      (code 1)
```
Réparation (retour à `no`), rechargement, contrôle de nouveau conforme (code 0).

## 5. Leçon apprise
1. **Durcir un accès, c'est risquer de se le fermer.** L'ordre d'opérations n'est pas un
   détail de confort, c'est ce qui sépare un durcissement d'un verrouillage. Nouvelle clé
   prouvée **avant** de retirer l'ancienne méthode ; seconde session ouverte en filet.
2. **Le contrôle lit `sshd -T`, pas le fichier.** La dérive a été écrite dans le fichier ;
   seule la configuration effective du démon fait foi. Lire la réalité, pas l'intention.
3. **`PermitRootLogin no` est une barrière indépendante de la clé.** Même une clé valide ne
   fait pas entrer root : deux verrous distincts, pas un seul.

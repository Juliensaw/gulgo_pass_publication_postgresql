# GULGO PASS — V1.3 : remédiation du rejeu de contexte d'identité

**Décision : architecture V1.2 non homologuée pour la production.**

## Modèle de menace

Le contexte actuel est `actor UUID + HMAC(secret, "gulgo-actor-v12:" || UUID)`.
Le secret reste confidentiel, mais le MAC est **statique** : toute personne qui obtient un MAC valide peut le rejouer tant que la clé n'est pas changée. Un GUC de session n'est pas un stockage confidentiel et n'est pas une preuve d'authentification indépendante.

## Modification cible — à implémenter et tester, non encore livrée

1. Le serveur API vérifie le JWT, ouvre une transaction avec une connexion exclusivement `gulgo_runtime`, puis calcule un contexte signé pour **cette transaction**.
2. La charge signée contient : version, UUID utilisateur, identifiant de transaction PostgreSQL, horodatage d'expiration UTC et identifiant de clé. Elle doit utiliser un encodage canonique strictement identique en Python et SQL.
3. La fonction SQL `gulgo_actor_id()` vérifie le HMAC, le format, l'expiration, l'identifiant de transaction et l'identifiant de clé. Toute absence, anomalie ou incohérence renvoie `NULL`.
4. Le secret n'est accessible qu'au propriétaire de la fonction `SECURITY DEFINER`. L'application ne dispose jamais d'un accès SQL direct au secret.
5. La rotation doit permettre une période de chevauchement contrôlée de deux clés, avec désactivation rapide de l'ancienne. Les clés sont provisionnées par un gestionnaire de secrets et jamais inscrites dans Git ou les logs.
6. Les accès PostgreSQL directs restent limités au service API ; la signature de contexte ne remplace pas l'isolation réseau.

## Limite importante

Une liaison à la transaction réduit le rejeu entre transactions, **mais ne protège pas automatiquement contre un adversaire qui peut exécuter du SQL arbitraire dans la transaction légitime**. L'API doit n'exécuter que des requêtes prédéfinies et paramétrées, et la surface des fonctions SQL doit être revue. Un nonce seul n'est pas une preuve d'absence de rejeu.

## Critères de recette

- Identité A correctement signée : lecture de A et écriture autorisée sur A.
- Identité A : aucune lecture ou écriture sur B.
- Changement de `app.current_user_id` sans nouvelle signature : rejet.
- MAC de la transaction T1 réutilisé dans T2 : rejet.
- MAC expiré, malformé ou signé par une clé révoquée : rejet.
- Absence de clé côté API ou SQL : échec fermé.
- Exécution par un login privilégié, ou hors `gulgo_runtime` : rejet.
- Compatibilité de tous les tests historiques et du parcours API de bout en bout.
- Revue indépendante des privilèges SQL, du JWT et des journaux.

**Condition de sortie :** ne pas fusionner la PR #3 vers une branche déployable avant implémentation, preuve CI et revue des critères ci-dessus.

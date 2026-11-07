# GULGO PASS V1.2 — décision de sécurité et conditions de déploiement

**Statut : NO-GO production.** Le passage des tests CI n'est pas une homologation de sécurité.

## État démontré
- PostgreSQL RLS et fonctions d'écriture contrôlées sont couverts par les tests d'intégration.
- Le contexte utilisateur est signé par HMAC-SHA256 et vérifié côté base, avec secret inaccessible à `gulgo_api` selon les droits SQL.
- Les tests d'acceptation vérifient la visibilité légitime et le rejet de modifications de l'identifiant sans MAC correspondant.
- Aucun calcul de score PASS n'est autorisé dans le MVP descriptif.

## Risques bloquants restants
1. **Rejeu de signature :** depuis la migration V1.3, le HMAC porte sur l'UUID utilisateur et l'identifiant de transaction PostgreSQL. Un test CI démontre le rejet d'une signature de T1 dans T2. **Le MAC n'a toujours pas d'expiration temporelle ni de rotation de clé.** Les GUC PostgreSQL restent modifiables par un client SQL, et un attaquant capable d'agir dans une transaction authentifiée conserve une surface d'attaque. La mitigation ne constitue pas une homologation.
2. **Gestion des clés :** il n'existe pas encore de provisionnement de production automatisé, de rotation coordonnée entre API et PostgreSQL, ni de procédure de révocation éprouvée.
3. **Authentification :** l'API vérifie des JWT HS256 ; il faut valider la provenance et la gestion des clés JWT, les droits des émetteurs et les conditions de révocation.
4. **Surface SQL :** une garde syntaxique sur les requêtes de l'API ne remplace ni une politique d'accès réseau stricte ni un audit SQL et des fonctions SECURITY DEFINER.
5. **Tests :** les suites automatisées utilisent des clés et utilisateurs synthétiques. Une revue indépendante, des tests de rejeu, et une recette de déploiement restent nécessaires.

## Procédure de provisionnement — environnement isolé uniquement
1. Générer une clé aléatoire de 32 octets ou plus à l'aide d'un générateur cryptographique reconnu, **hors dépôt Git**. Exemple : `openssl rand -hex 32`.
2. Stocker sa représentation hexadécimale dans un gestionnaire de secrets ; fournir la même valeur à l'API via `GULGO_ACTOR_HMAC_SECRET` et à PostgreSQL via une opération administrative de provisionnement contrôlée.
3. L'opération SQL, effectuée par un administrateur propriétaire, doit insérer la valeur binaire décodée dans `public.gulgo_identity_secret`. Ne jamais placer la clé dans les scripts de migration versionnés, dans les journaux, ni dans les arguments de commande visibles.
4. Vérifier que les rôles `gulgo_runtime` et `gulgo_api` n'ont aucun droit direct sur la table de secret ; vérifier les privilèges des rôles et les accès réseau.
5. Tester le refus en l'absence de secret, le fonctionnement d'un utilisateur autorisé et l'interdiction d'accès à un autre dossier.

**Attention :** le provisionnement décrit est une procédure de préparation, **pas** une approbation de production. Ne pas déployer sans validation des risques résiduels de rejeu, de gestion des clés et d'exécution SQL au sein d'une transaction authentifiée.

## Critères de GO (tous obligatoires)
- [x] Deux workflows CI réussis sur le commit V1.3 `315861d7` (à refaire sur le commit de fusion envisagé).
- [ ] Signatures anti-rejeu : liaison à la transaction implémentée et testée ; expiration temporelle et stratégie contre l'exécution SQL arbitraire encore à valider.
- [ ] Gestion des secrets : provisionnement, rotation, sauvegarde, révocation et accès audités.
- [ ] Accès réseau PostgreSQL limité aux composants explicitement autorisés.
- [ ] Tests d'intégration avec une vraie connexion `gulgo_runtime` et parcours API de bout en bout.
- [ ] Revue de sécurité des fonctions `SECURITY DEFINER`, des politiques RLS et des droits SQL.
- [ ] Plan de réponse à incident, journalisation sans fuite de jetons ni signatures.
- [ ] Validation fonctionnelle : six dimensions descriptives, **aucun scoring** sans approbation méthodologique.

**Décision courante : NO-GO.** Maintenir la PR en brouillon tant que les critères ne sont pas remplis.

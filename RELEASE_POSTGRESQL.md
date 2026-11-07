# GULGO PASS — Publication et recette PostgreSQL

## État de vérification
- L'archive source V1.1 comporte les migrations SQL 001–006, les tests Python et les assertions SQL.
- Tests Python de l'archive : 50 réussis lors de la vérification locale du 7 novembre 2026.
- Précontrôle de l'archive : réussi.
- **Le dépôt GitHub est incomplet : ne pas considérer les fichiers présents comme une publication intégrale de l'archive.**
- **Aucune recette PostgreSQL 16 n'a été exécutée avec succès et vérifiée.**
- Ne jamais utiliser de données réelles ou de secrets de production pour la recette.

## Critères d'acceptation
1. Comparer chaque fichier du dépôt à l'archive avant fusion ; certains fichiers ont été publiés séparément et peuvent diverger.
2. Publier toutes les migrations SQL 001–006, le code Python, les tests et les scripts d'intégration.
3. Exécuter le workflow GitHub Actions avec PostgreSQL 16 jetable.
4. Vérifier le rôle applicatif sans BYPASSRLS, les restrictions inter-entreprises, les écritures contrôlées, l'audit et les contraintes de correction.
5. Conserver les logs d'exécution et corriger toute erreur avant pilote.

## Sécurité
Le compte propriétaire de la base ne doit pas servir les requêtes de l'API. Le paramètre de session `app.current_user_id` ne constitue pas à lui seul une authentification sûre. Les fonctions `SECURITY DEFINER` nécessitent un audit avant utilisation réelle.

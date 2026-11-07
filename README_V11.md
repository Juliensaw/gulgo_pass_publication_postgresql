# GULGO PASS V1.1 — dépôt privé et recette d'intégration

## Statut vérifié
- Les sources V1.0 ont été conservées.
- La configuration CI a été renforcée et une revue des risques de déploiement a été ajoutée.
- Les tests Python peuvent être exécutés localement avec `python -m pytest -q tests`.
- **Aucun test PostgreSQL n'a été exécuté dans l'environnement de préparation de cette archive.**
- **Aucun dépôt GitHub n'a été créé ni aucune exécution GitHub Actions confirmée.**

## Première exécution GitHub
1. Créer un dépôt **privé** `gulgo-pass-backend` sur GitHub, sans initialiser README.
2. Depuis le dossier extrait, exécuter :
   ```sh
   git init
   git branch -M main
   git add .
   git commit -m "Initial GULGO PASS backend security baseline"
   git remote add origin https://github.com/ORGANISATION/gulgo-pass-backend.git
   git push -u origin main
   ```
3. Ouvrir Actions > `PostgreSQL integration and Python tests` et vérifier **chaque étape**, pas uniquement le badge global.
4. Si une migration échoue, récupérer les logs du job et corriger le SQL avant tout déploiement.
5. Ne jamais enregistrer de jeton, mot de passe de production, pièce justificative réelle ou donnée client dans le dépôt.

## Blocages de mise en production (priorité haute)
- Le rôle SQL `gulgo_api` est `NOLOGIN`; il n'existe pas encore de rôle de connexion applicatif provisionné avec droits stricts. La configuration `GULGO_DATABASE_URL` ne doit jamais pointer vers `gulgo_owner`.
- Le contexte SQL `app.current_user_id` est modifiable par un client SQL; seule l'API qui vérifie le JWT peut le fixer. Les identifiants de base ne doivent jamais être exposés aux clients.
- Les fonctions `SECURITY DEFINER` ont un `search_path` contenant `public`. La sécurité dépend de l'interdiction de CREATE sur ce schéma pour les rôles non fiables et doit être auditée.
- Les tests SQL actuellement lancés en se connectant comme propriétaire puis en changeant de rôle ne remplacent pas une recette utilisant un compte applicatif de connexion distinct.
- Le schéma utilise des règles d'immutabilité; vérifier leur compatibilité avec les opérations métier et la rétention/suppression légale des données.
- La clé HS256 prototype doit être remplacée ou protégée par un gestionnaire de secrets avec rotation, vérification du fournisseur d'identité et des clés.
- Ne pas utiliser de données économiques réelles ni publier l'API tant que la recette, la revue sécurité et la gestion des accès ne sont pas validées.

## Prochaine itération technique après résultats CI
- Corriger les erreurs SQL réellement observées.
- Provisionner un rôle `gulgo_runtime LOGIN` non propriétaire et non superutilisateur, avec droits minimaux, et vérifier une connexion applicative effective.
- Exécuter les scénarios A/B avec ce rôle, puis ajouter des tests de révocation de mandat et de concurrence.
- Conserver `scoring_enabled=false` : aucune note officielle automatisée.

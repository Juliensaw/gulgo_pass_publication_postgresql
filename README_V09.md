# GULGO PASS — Backend V0.9 : correction de compatibilité RLS

## Diagnostic
Les migrations 002/003 imposaient FORCE RLS sans politiques INSERT sur les tables métier. Le rôle propriétaire, utilisé par les fonctions SECURITY DEFINER, était donc soumis aux mêmes restrictions : les créations et même les fixtures SQL pouvaient échouer. **Ce problème a été détecté par inspection statique, non par exécution PostgreSQL.**

## Correction
La migration 006 retire **FORCE** RLS sur 17 tables, sans désactiver RLS. Le rôle applicatif `gulgo_api` reste distinct du propriétaire, NOLOGIN, NOBYPASSRLS, sans droit direct d'écriture. Les fonctions SECURITY DEFINER exécutées par le propriétaire peuvent écrire, sous réserve de leurs vérifications d'habilitation. Cela transfère davantage de confiance au propriétaire et à ces fonctions : leur code et leurs privilèges doivent être audités.

## Recette sur base jetable uniquement
`cp .env.example .env` puis renseigner le mot de passe; `set -a; . ./.env; set +a`; `./integration/run_postgres_tests.sh`; `python -m pytest -q tests`; `docker compose down -v`.

IMPORTANT : supprimer tout ancien conteneur/volume de test avant réinitialisation : les scripts d'init ne sont exécutés que sur une base neuve. Ne jamais exécuter cette recette sur une base contenant des données réelles.

## Limites bloquantes
- PostgreSQL/Docker non disponibles ici : aucun test SQL réel effectué.
- Le compte `gulgo_owner` Docker est superutilisateur et ne convient pas comme rôle propriétaire de production. Séparer les rôles de migration, propriétaire non-superutilisateur, et connexion applicative; refaire les tests.
- `app.current_user_id` reste une variable de session falsifiable si une connexion SQL arbitraire est exposée. L'API doit utiliser un compte restreint et une identité JWT validée; ne jamais exposer la base aux utilisateurs.
- Les fonctions SECURITY DEFINER doivent faire l'objet d'un audit indépendant (permissions, `search_path`, gestion des erreurs, mandats révoqués).
- Aucune donnée réelle ni score officiel avant recette d'intégration et audit.

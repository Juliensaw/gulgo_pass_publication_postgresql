# GULGO PASS V0.7 — recette PostgreSQL reproductible (non exécutée ici)

## Correctifs
- Docker Compose initialise désormais les migrations 001, 002, 003 **et 004** (la V0.6 omettait 004).
- Le lanceur d’intégration exécute les assertions de lecture/RLS et de création/observation/audit.
- Les tests de sécurité vérifient les refus d’écriture inter-entreprises et la journalisation transactionnelle.

## Exécution (base jetable uniquement)
1. Installer Docker + Docker Compose.
2. Depuis ce dossier, créer `.env` avec `POSTGRES_PASSWORD=<mot-de-passe-fort-de-test>`.
3. `set -a; . ./.env; set +a; ./integration/run_postgres_tests.sh`
4. `python -m pytest -q tests`
5. Nettoyer avec `docker compose down -v`.

ATTENTION : le volume de données est temporaire ; ne pas y mettre de données réelles.

## État de validation
Tests Python statiques et unitaires exécutables dans l’environnement de génération. PostgreSQL et Docker absents : aucune migration ni assertion SQL n’a été exécutée sur un serveur réel. Les scripts SQL constituent un banc de recette **à faire tourner**, pas une preuve d’isolation.

## Risques critiques non résolus
- Le GUC `app.current_user_id` est falsifiable en cas d’accès SQL arbitraire ; aucune connexion SQL directe ne doit être exposée.
- Les fonctions SECURITY DEFINER et leur propriétaire, la résolution des politiques RLS, les privilèges et les accès doivent être vérifiés sur PostgreSQL.
- Authentification JWT HS256 de prototype, sans service d’identité de production.
- Contrôles métier incomplets, erreurs API non classées, concurrence/idempotence non traitées.
- Ne pas activer le Score Pass officiel, ni héberger de données réelles.

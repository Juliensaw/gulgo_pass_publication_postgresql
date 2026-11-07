# GULGO PASS — Backend V0.8 (durcissement et audit de recette)

## Modifications
- Migration `sql/005_integrity_hardening.sql`: index unique empêchant deux corrections d'une même observation, interdiction de l'auto-remplacement, révocation explicite de privilèges.
- Montage Docker de la migration 005 et ajout de `integration/006_hardening_assertions.sql` au lanceur.
- Quatre tests statiques supplémentaires.

## Exécution sur une base **jetable**
```sh
cp .env.example .env
# Modifier POSTGRES_PASSWORD dans .env
set -a; . ./.env; set +a
./integration/run_postgres_tests.sh
python -m pytest -q tests
docker compose down -v
```
Le volume est temporaire et les migrations Docker ne se rejouent automatiquement que lors d'une **nouvelle initialisation**. Ne pas utiliser de données réelles.

## Limites et risques critiques
1. **PostgreSQL/Docker non exécutés dans l'environnement de création**. Les assertions SQL doivent encore être vérifiées sur serveur réel; aucun feu vert de sécurité n'est accordé.
2. Le rôle propriétaire de la base Docker est superutilisateur; `SECURITY DEFINER` et les politiques RLS doivent être revus sous un propriétaire non-superutilisateur avant production.
3. `app.current_user_id` reste falsifiable par un client qui disposerait d'un accès SQL arbitraire. Ne jamais exposer de connexion directe.
4. JWT HS256 est expérimental, sans service d'identité de production.
5. Le test d'isolation n'est pas un audit de sécurité exhaustif; l'idempotence, les droits sur les pièces, les contrôles de concurrence et la révocation de mandats restent à développer.
6. Le score officiel est désactivé. Ne pas héberger de données réelles.

## Jalon suivant
Exécuter les trois suites SQL sur PostgreSQL réel; traiter les échecs et conserver les journaux. Ensuite seulement, passer à l'API de création de sujets et aux habilitations administratives.

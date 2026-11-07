# GULGO PASS — V1.0 : recette PostgreSQL automatisable

## Livrable
Cette version conserve le backend V0.9 et ajoute un pipeline GitHub Actions (`.github/workflows/postgresql-integration.yml`) pour exécuter **les tests Python puis les assertions SQL sur une base PostgreSQL 16 jetable**. Le script de recette vérifie aussi la présence des objets critiques avant de lancer les assertions, pour détecter une initialisation SQL incomplète.

## Exécution locale (Docker requis)
Depuis la racine du projet :

```sh
export POSTGRES_PASSWORD='un-mot-de-passe-temporaire-fort'
python -m pip install -r requirements-v05.txt
python -m pytest -q tests
./integration/run_postgres_tests.sh
docker compose down -v --remove-orphans
```

Le pipeline CI nécessite que **ce répertoire soit la racine du dépôt GitHub** et qu'un runner Docker soit disponible. Ne pas utiliser de base de données réelle. La configuration Docker existante utilise un propriétaire superutilisateur de test, **pas un modèle de déploiement de production**.

## État des validations
- Tests Python : exécutables dans cet environnement ; résultat communiqué séparément.
- Migrations PostgreSQL et assertions SQL : **non exécutées ici**, faute de Docker et PostgreSQL.
- CI GitHub : fichier fourni, **non déclenché** ; aucun statut vert revendiqué.
- Les scénarios SQL de V0.9 ne prouvent pas à eux seuls la résistance à une usurpation de `app.current_user_id` par un client SQL malveillant.

## Critère de sortie
Exiger une exécution verte du pipeline sur PostgreSQL réel, une revue indépendante des fonctions `SECURITY DEFINER`, et une séparation des comptes propriétaire / migration / application avant toute donnée économique réelle. Le Score Pass officiel reste désactivé.

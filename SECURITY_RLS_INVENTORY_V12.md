# GULGO PASS — Inventaire de sécurité RLS / identité V1.2

Statut : inventaire partiel, fondé sur les fichiers consultés dans la branche `staging/source-v11-verification`. Aucun test exécuté dans cette étape.

## Dépendances confirmées
| Surface | Fichier | Constat | Priorité |
|---|---|---|---|
| API, toutes requêtes SQL authentifiées | `src/api/main.py` | `query_as_actor` exécute `SET LOCAL ROLE gulgo_api`, contrôle le login `gulgo_runtime`, puis `set_config('app.current_user_id', actor, true)`. | Critique |
| Lecture dossiers | `src/api/main.py` | Requêtes directes `economic_subject` / `pass_dossier`, protection attendue par RLS. | Critique |
| Observations | `src/api/main.py` | Historique borné à 100 observations, contrôlé par visibilité du dossier. | Élevée |
| Catalogue | `src/api/main.py` | Vérification de visibilité du dossier puis seconde requête de métadonnées. | Élevée |
| PDF | `src/api/main.py` | Compose trois appels séparés (dossier, catalogue, observations), donc transactions séparées. | Élevée |
| Écriture | `src/api/main.py` | `gulgo_create_dossier` et `gulgo_append_observation` sont invoquées sous identité de session. | Critique |
| Fonctions privilégiées | `sql/008_definer_search_path.sql` | Deux fonctions `SECURITY DEFINER` fixent le `search_path` à `pg_catalog, public, pg_temp` ; ne sécurise pas la provenance de l'identité. | Critique |
| Test d'attaque lecture | `integration/011_guc_spoofing_demonstration.sql` | Changement de GUC A→B suivi d'une lecture du dossier B : attaque attendue et documentée. | Critique |
| Test d'attaque écriture | `integration/018_guc_spoofed_write_demonstration.sql` | Référencé par le runner ; contenu à examiner. | Critique |
| Connexions réelles | `integration/run_postgres_tests.sh` | Connexions sous `gulgo_runtime` et fixtures jetables ; test A/B ne prouve pas l'impossibilité de falsifier la GUC. | Élevée |

## Lacunes de l'inventaire
Les définitions complètes des migrations initiales, les politiques RLS et les GRANT/REVOKE n'ont pas encore été reconstitués. Les recherches de code GitHub n'ont renvoyé aucun résultat sur la branche par défaut ; elles ne prouvent pas l'absence de ces objets. Le chemin exact des migrations doit être établi à partir du manifeste du dépôt, du workflow ou de l'archive source.

## Critères pour passer à la conception
1. Obtenir le texte de toutes les politiques RLS, des fonctions privilégiées et des privilèges effectifs.
2. Tracer chaque route et chaque fonction vers ses contrôles d'autorisation.
3. Documenter les acteurs ayant un accès SQL direct, ainsi que les mécanismes d'authentification et les secrets.
4. Choisir une frontière de confiance qui reste sûre même si une GUC est modifiée par un appelant SQL non privilégié.
5. Écrire des tests négatifs de lecture **et** d'écriture inter-utilisateurs, puis les exécuter sur PostgreSQL jetable.

## Décision
Ne pas présenter le contrôle actuel de `gulgo_runtime` comme une correction de l'usurpation SQL. Ne pas fusionner vers `main` ni autoriser des données réelles.

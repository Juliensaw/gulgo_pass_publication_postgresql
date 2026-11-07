# Revue de sécurité pré-fusion — GULGO PASS V1.1

Date : 2026-11-07. Statut : **BLOQUANT POUR LA PRODUCTION**.

## Périmètre examiné
`src/api/main.py`, `sql/002_integrity_security.sql`, `sql/003_access_roles.sql`, `sql/004_controlled_writes.sql` sur `staging/source-v11-verification`.

## Constatations

### SEC-01 — Identité applicative falsifiable au niveau SQL (critique)
Les politiques RLS et les fonctions `SECURITY DEFINER` se fondent sur `current_setting('app.current_user_id')`, une variable personnalisée PostgreSQL. Un rôle SQL autorisé à invoquer ces fonctions peut fixer cette variable à l'UUID d'un autre utilisateur avec `set_config`. La validation JWT dans FastAPI réduit le risque à la frontière HTTP mais ne rend pas ce contexte SQL non falsifiable. **Ne pas exposer l'accès SQL direct au rôle de connexion applicatif, ni à des utilisateurs ou extensions non fiables.** Avant production : concevoir un contexte d'identité infalsifiable au niveau DB ou imposer une frontière de confiance stricte et testée, avec un compte de connexion à privilèges minimaux.

### SEC-02 — Connexion de l'API non attestée comme moindre privilège (élevé)
`gulgo_api` est `NOLOGIN`. `src/api/main.py` utilise `GULGO_DATABASE_URL` sans imposer ni vérifier l'identité effective du rôle SQL. Si l'URL pointe vers le propriétaire des tables, celui-ci peut contourner RLS depuis la migration 006. Avant production : compte LOGIN dédié, non propriétaire, `NOBYPASSRLS`, accès au rôle applicatif selon un schéma explicitement audité ; test de démarrage vérifiant `current_user`, `rolbypassrls` et la propriété des tables.

### SEC-03 — SECURITY DEFINER et chemin de recherche (élevé)
Les fonctions d'écriture utilisent `SET search_path = public, pg_temp`. Les noms non qualifiés sont sensibles à la configuration et aux droits sur le schéma. Avant production : qualifier les objets `public.`, fixer un chemin de recherche sûr, révoquer CREATE aux rôles non fiables et tester la résolution des fonctions et opérateurs.

### SEC-04 — Couverture des tests (élevé)
Le workflow n°22 a réussi : 50 tests Python et assertions PostgreSQL, mais les scénarios ne démontrent pas l'absence d'usurpation du contexte SQL, ni le fonctionnement avec un compte LOGIN applicatif non propriétaire, ni une analyse des privilèges des fonctions. Ajouter des tests négatifs reproduisant ces menaces.

### SEC-05 — Divergence archive / dépôt (moyen)
Plusieurs fichiers ont été publiés individuellement avant la synchronisation. Comparer leurs empreintes SHA-256 à l'archive V1.1 avant fusion.

## Décision
La PR reste en brouillon. **Aucune fusion vers main ni utilisation de données réelles tant que SEC-01 et SEC-02 ne sont pas corrigés et validés.** Le succès du workflow CI est une condition nécessaire mais insuffisante pour la mise en production.

# Décision de sécurité — Identité applicative et RLS (V1.1)

**Statut : BLOQUANT — pas de fusion de production.**

## Constat vérifié
Le test `integration/011_guc_spoofing_demonstration.sql` prouve qu'un client capable
d'exécuter du SQL sous `gulgo_api` peut remplacer `app.current_user_id` par
l'UUID d'un autre utilisateur et accéder à ses dossiers. Le test passe lorsque
l'attaque réussit : il ne constitue PAS un test de non-régression de sécurité.

Les migrations 007 et les garde-fous API imposent un compte de connexion
`gulgo_runtime`, sans privilèges propriétaires, avec `SET LOCAL ROLE gulgo_api`.
Cela réduit les risques de mauvaise configuration mais ne protège pas contre
l'exécution arbitraire de SQL via un accès direct à la base, une injection SQL
ou une fonction SQL dangereuse.

## Frontière de confiance du pilote
- Aucun utilisateur final, navigateur, partenaire ou prestataire ne reçoit
  d'identifiants PostgreSQL.
- Seul le backend authentifié possède le secret de connexion.
- Les requêtes SQL restent statiques et paramétrées; les identifiants SQL,
  fragments de requêtes et noms de tables ne proviennent jamais du client.
- Le backend valide la signature, l'émetteur, l'audience et l'expiration du JWT.
- Les secrets de connexion et JWT sont provisionnés hors dépôt.
- L'accès réseau à PostgreSQL est limité au backend et aux opérateurs autorisés.
- Les rôles `gulgo_runtime` et `gulgo_api` ne sont jamais utilisés pour des
  connexions interactives ni exposés aux utilisateurs finaux.

Ces mesures sont **des exigences à vérifier en déploiement**, pas des garanties
automatiquement démontrées par le CI actuel.

## Décision d'architecture avant production
La solution durable doit établir l'identité depuis un mécanisme que l'appelant
SQL ne peut pas falsifier (par exemple un service de confiance qui applique
l'autorisation hors des GUC, avec isolation des privilèges), puis vérifier
l'accès inter-tenant en tests adversariaux de bout en bout.

**Critères de sortie du blocage :**
1. Un utilisateur A ne peut ni lire ni modifier les dossiers de B, via toutes
   les routes publiques et les fonctions SQL exposées.
2. Les identifiants PostgreSQL ne sont pas accessibles aux utilisateurs finaux.
3. Les tests de connexions et d'autorisations utilisent réellement
   `gulgo_runtime`, pas un rôle propriétaire.
4. Les contrôles réseau, la rotation des secrets, les journaux d'audit et les
   tests d'injection SQL sont vérifiés dans l'environnement de pilote.
5. Revue de sécurité indépendante avant ouverture à des données réelles.

**Interdiction :** ne pas retirer le test démontrant l'attaque simplement pour
obtenir un CI vert. Le remplacer par un test négatif seulement après la mise
en place d'une barrière réellement efficace.

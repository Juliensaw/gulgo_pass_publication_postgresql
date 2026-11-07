# Architecture cible de l'identité PASS — décision technique V1.2

**État : conception proposée, non activée.** Le pilote reste bloqué pour les données réelles.

## Pourquoi les contrôles de rôle ne suffisent pas

`gulgo_runtime` est un compte technique partagé par les requêtes HTTP. Les
politiques RLS actuelles utilisent `app.current_user_id`, une GUC PostgreSQL
librement modifiable par le rôle SQL. Le test
`integration/011_guc_spoofing_demonstration.sql` démontre une usurpation
inter-dossiers. Des contrôles supplémentaires sur les attributs du rôle
n'empêchent pas ce scénario.

## Choix cible : contexte d'identité signé et vérifié dans PostgreSQL

1. Le client HTTP fournit un JWT d'accès signé, à durée de vie courte,
   vérifié par FastAPI (signature, émetteur, audience, dates).
2. La connexion `gulgo_runtime` n'obtient aucun secret de vérification
   permettant de fabriquer une identité arbitraire.
3. La transaction transmet le **jeton signé original**, pas un UUID
   autonome, à une fonction PostgreSQL de vérification.
4. Une fonction `SECURITY DEFINER` à chemin de recherche figé vérifie la
   signature et les revendications du jeton avec une clé **inaccessible**
   à `gulgo_api` et `gulgo_runtime`, puis extrait `sub`.
5. Les politiques RLS et les fonctions d'écriture utilisent exclusivement
   l'identité vérifiée. La GUC `app.current_user_id` est supprimée de la
   chaîne d'autorisation après migration.
6. Un SQL arbitraire pourra remplacer le jeton présenté, mais **ne pourra
   pas fabriquer un jeton valide pour un autre utilisateur** sans la clé
   de signature ou un jeton volé. Le risque de vol de jeton reste distinct
   et nécessite protection, rotation et révocation.

## Conditions de mise en œuvre

- Ne pas stocker une clé HMAC en clair dans le dépôt, une migration SQL,
  un log ou une variable lisible par le rôle applicatif.
- Préférer une signature asymétrique (Ed25519 ou RSA selon l'extension et
  le mécanisme de vérification retenus) : PostgreSQL ne détient alors que
  la **clé publique** et ne peut pas émettre de jetons.
- Le schéma privé des fonctions de vérification doit refuser
  `USAGE`, `SELECT` et `CREATE` aux rôles non fiables, avec des
  autorisations `EXECUTE` minimales sur la fonction d'identité.
- Vérifier `alg` explicitement (liste fermée), `kid` via un registre
  contrôlé, la signature cryptographique, `iss`, `aud`, `sub` UUID,
  `exp`, `nbf` et `iat`. Refuser les valeurs absentes, expirées,
  malformées ou hors tolérance d'horloge.
- L'évaluation du jeton doit être **transactionnelle** et ne pas être
  mise en cache entre connexions ni utilisateurs.
- Auditer les fonctions `SECURITY DEFINER`, les privilèges
  `PUBLIC`, les schémas de recherche et les droits sur les clés.
- Ne jamais mettre la clé privée ou un JWT réel dans des fixtures CI.

## Tests de sortie obligatoires

- A et B, chacun avec un JWT valide différent : lecture, écriture,
  rapport PDF et historiques isolés.
- A remplace son `sub` par B sans nouvelle signature : refus.
- A modifie directement `app.current_user_id` : aucun effet.
- SQL arbitraire sous `gulgo_runtime` : aucune lecture inter-dossiers
  sans jeton signé appartenant à B.
- Jeton expiré, signature invalide, `alg=none`, mauvaise audience,
  mauvais émetteur, mauvaise clé : refus.
- Tests de rotation de clés et de révocation.
- Audit indépendant et déploiement pilote sous contrôle.

## Critère de bascule

Ne pas substituer un vérificateur cryptographique expérimental au système
actuel sans suite d'intégration et audit. La bascule doit être atomique :
migration SQL, API, RLS, fonctions d'écriture, tests d'attaque et procédure
de rotation. La réussite de CI seule n'autorise pas la production.

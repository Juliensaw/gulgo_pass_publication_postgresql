# GULGO PASS — Backend

Prototype technique de la plateforme GULGO PASS. Les tests PostgreSQL et l'isolation des données doivent être validés avant toute utilisation réelle.

Consulter `RELEASE_POSTGRESQL.md` pour la procédure de recette.

## Démonstrateur web PASS (données fictives uniquement)

Une interface de démonstration est servie par FastAPI sur `GET /demo/pass`.
Elle permet de consulter les sujets économiques et les dossiers visibles,
de créer un dossier brouillon pour un sujet existant et de lire l'historique
des observations. Les six dimensions métier sont affichées comme **repères**,
pas comme formulaires opérationnels; aucun score n'est calculé.

Pour tester localement dans un environnement isolé :

```sh
python -m pip install -r requirements-v05.txt
uvicorn src.api.main:app --host 127.0.0.1 --port 8000
```

Ouvrir `http://127.0.0.1:8000/demo/pass`.
Les routes de dossiers exigent un JWT de **test** valide (émetteur
`gulgo-auth`, audience `gulgo-api`) et un backend PostgreSQL configuré.
L'interface ne crée pas de compte, ne délivre pas de jetons et ne fonctionne
pas avec une simple installation vierge sans données de démonstration.
Ne pas coller de jeton de production dans cet écran. Le jeton saisi reste
en mémoire JavaScript et disparaît au rechargement.

Pour lancer les tests Python : `python -m pytest -q tests`.
Pour la recette PostgreSQL, utiliser uniquement la base jetable prévue par
le script `integration/run_postgres_tests.sh`.

**Non prêt pour l'exploitation réelle :** les contrôles de sécurité restent
incomplets, notamment le risque d'usurpation de l'identité par GUC depuis
une connexion SQL arbitraire. Voir `SECURITY_IDENTITY_DECISION_V11.md`
et `MVP_DELIVERY_PLAN_V11.md`. Aucun traitement de données personnelles
ou économiques réelles n'est autorisé dans le démonstrateur.

## Page institutionnelle GULGO — prototype

L'API sert aussi une première page d'accueil institutionnelle sur `GET /`.
Elle présente les publics prioritaires (indépendants, TPE, PME), les offres
PASS / TRUST / STRATEGY / DIASPORA / MARKET et le parcours envisagé.

L'action principale « Découvrir la pré-évaluation » renvoie à une section
informative, **pas à un outil de pré-évaluation opérationnel**. Aucun score,
décision d'admissibilité, formulaire de contact ou collecte de données n'est
implémenté sur cette page. Les services non encore opérationnels sont indiqués
comme tels.

Pour la tester localement, démarrer FastAPI comme indiqué plus haut et ouvrir
`http://127.0.0.1:8000/`. Ce prototype n'est pas un site public déployé
et ne doit pas être considéré comme une validation commerciale.

Étapes de travail suivantes : validation du contenu institutionnel, création
de la pré-évaluation selon les règles métier approuvées, puis mise en place
d'une navigation et d'une authentification utilisables vers l'application PASS.

## Préparation à la pré-évaluation — démonstrateur sans collecte

La page institutionnelle dirige maintenant vers `GET /demo/pre-evaluation`.
Ce questionnaire propose quatre questions qualitatives sur la préparation
d'une activité économique. Il affiche localement une liste d'éléments à
clarifier. Aucune réponse n'est transmise au serveur ou conservée en stockage
navigateur ; aucun nom, chiffre d'affaires, numéro d'identité ou justificatif
n'est demandé.

**Ce n'est pas la pré-évaluation GULGO officielle.** Les statuts
« Compatible », « Partiellement compatible » et « Non compatible » ne sont
pas calculés : leurs critères et leurs conséquences doivent être approuvés
avant implémentation et testés sur des cas représentatifs. Le parcours ne
constitue pas une inscription ni une promesse d'accès au financement.

À ce stade, la présence d'une page et de tests unitaires ne constitue ni
une validation ergonomique par des utilisateurs ni une autorisation de mise
en production. Voir `MVP_DELIVERY_PLAN_V11.md` pour les conditions de sortie.

# GULGO PASS — Plan de remédiation de l'identité V1.2

Statut : PLAN TECHNIQUE, NON VALIDÉ POUR PRODUCTION.

## Constat vérifié
Le test `integration/011_guc_spoofing_demonstration.sql` démontre qu'un acteur ayant la capacité d'exécuter du SQL arbitraire sous `gulgo_api` peut définir `app.current_user_id` avec l'identifiant d'un autre utilisateur et lire ses dossiers. Le durcissement du `search_path` des fonctions `SECURITY DEFINER` ne supprime pas cette vulnérabilité.

## Invariant de sécurité recherché
Aucune valeur de session modifiable par un appelant SQL ne doit suffire à conférer les droits d'un autre utilisateur. Une autorisation doit être dérivée d'une identité authentifiée et vérifiée à une frontière de confiance contrôlée, puis appliquée de manière cohérente aux lectures, écritures, exports et fonctions privilégiées.

## Travaux à effectuer (sans migration destructive)
1. Inventorier toutes les politiques RLS, fonctions `SECURITY DEFINER`, vues et routes API qui consultent `app.current_user_id`, ainsi que les privilèges effectifs des rôles.
2. Définir la frontière de confiance et un mécanisme d'autorisation non falsifiable par un client SQL non privilégié. Comparer au moins : (a) isolation de l'accès SQL au seul backend avec autorisation explicite côté service et rôles SQL minimaux ; (b) identités/rôles SQL distincts provisionnés par un composant de confiance. Évaluer l'exploitation, le coût et les chemins de contournement avant de choisir.
3. Implémenter sur une branche de travail dédiée, sans exposer de secrets ni accepter une simple substitution de GUC comme correctif.
4. Tester les parcours A/B avec JWT différents et connexions séparées ; vérifier lecture, création, modification, suppression, catalogue, observations et PDF. Tester injection SQL, fonctions privilégiées, connexions directes et accès réseau.
5. Transformer le test d'attaque en test négatif uniquement après preuve de correction ; conserver la démonstration historique clairement identifiée.
6. Faire revoir indépendamment la conception, les privilèges et les résultats de tests.

## Critères de sortie
- Aucune route publique ne donne accès aux ressources d'un autre utilisateur.
- Aucun acteur non privilégié pouvant exécuter du SQL ne peut s'attribuer l'identité ou les droits d'un autre acteur via une GUC ou une fonction.
- Les tests de régression et adversariaux passent sur une base jetable.
- Les secrets, restrictions réseau et journaux sont contrôlés dans l'environnement cible.
- Revue de sécurité indépendante documentée.

## Interdictions jusqu'à validation
Ne pas fusionner vers `main`, ne pas utiliser de données économiques/personnelles réelles, ne pas retirer le test démontrant l'attaque pour rendre le CI vert.

## État
Ce document prépare la recette suivante. Il ne constitue ni une implémentation du correctif, ni un résultat d'exécution des tests.

# GULGO PASS — Plan de livraison du MVP

**Statut : cadrage opérationnel, non-autorisation de production.**
**Produit :** infrastructure de crédibilité économique pour indépendants et PME ; GULGO n'est pas un prêteur.

## Objectif de la première livraison
Permettre à un utilisateur autorisé de créer un dossier pour son activité,
renseigner les informations selon les six dimensions PASS, associer des
justificatifs, faire examiner les données et télécharger un rapport
**descriptif** retraçant les informations, leurs sources et leurs limites.

**Hors périmètre V1 :** notation automatique, octroi de crédit, garantie
financière, place de marché, algorithme de décision automatisée et intégration
de partenaires financiers. `scoring_enabled` reste `false`.

## Six dimensions métier — ordre impératif
1. Identité & existence
2. Traçabilité & qualité des données
3. Activité & régularité économique
4. Discipline & engagements
5. Performance & résilience
6. Formalisation & gouvernance

## Registre priorisé et critères de réception

| ID | Priorité | Fonctionnalité | État vérifié | Critère d'acceptation |
| --- | --- | --- | --- | --- |
| SEC-01 | P0 | Isolation multi-entreprises | Partielle, vulnérabilité GUC documentée | Un compte A ne lit ni ne modifie les données de B par les routes API et interfaces SQL exposées ; tests négatifs réussis |
| SEC-02 | P0 | Authentification et rôles | JWT et rôles SQL présents ; parcours complet non testé | Connexion réelle, expiration, révocation, déconnexion et permissions testées |
| BE-01 | P0 | Création et lecture des dossiers | API présente | Un propriétaire autorisé crée et retrouve son dossier ; accès interdit aux autres |
| BE-02 | P0 | Collecte des observations | API présente | Valeurs, états manquants, périodes et corrections tracées sans écrasement |
| BE-03 | P0 | Gestion des justificatifs | Modèle de données présent ; flux complet non démontré | Téléversement, contrôle de type/taille, stockage privé, empreinte, association et consultation autorisée |
| UX-01 | P0 | Interface d'inscription et espace personnel | Non démontrée | Utilisateur authentifié navigue et retrouve ses dossiers |
| UX-02 | P0 | Formulaire guidé en six dimensions | Non démontré | Saisie, sauvegarde, reprise, validation et statut de complétude |
| WF-01 | P0 | Workflow de revue | États de dossier en base ; parcours non démontré | Soumission, contrôle, demande de correction, décision et audit des transitions |
| REP-01 | P0 | Rapport PASS descriptif | Non démontré | PDF horodaté avec six dimensions, sources, éléments non vérifiés et absence de score |
| QA-01 | P0 | Recette bout en bout | Tests SQL et Python existants | Deux utilisateurs distincts réalisent le parcours complet ; aucune fuite inter-tenant |
| OPS-01 | P0 | Exploitation du pilote | Non démontrée | Sauvegarde/restauration, surveillance, gestion des secrets, journalisation, procédure d'incident |
| GOV-01 | P0 | Protection des données | Non démontrée | Base légale, minimisation, durées de conservation, droits des personnes et contrôle d'accès documentés |
| SCORE-01 | P2 | Score PASS | Désactivé | Méthodologie métier validée, versionnée, explicable et auditée avant activation |

Les mentions « non démontré » ne signifient pas nécessairement « inexistant » :
elles indiquent que la fonctionnalité n'a pas été vérifiée dans le code examiné.

## Séquence de réalisation

### Lot A — Sécurité et contrat produit (bloquant)
- Fermer la frontière d'identité SQL : ne pas considérer une GUC client comme
  une preuve d'identité.
- Définir les rôles métier, les transitions d'état et les autorisations.
- Écrire les scénarios d'acceptation A/B et les tests de non-régression.
- Valider le contenu du rapport descriptif avec des utilisateurs pilotes.

**Sortie :** modèle d'autorisation documenté, tests adversariaux négatifs
et parcours métier approuvé.

### Lot B — Dossier et preuves
- Finaliser la gestion des comptes et des sujets économiques.
- Développer les opérations sur les justificatifs et leur traçabilité.
- Implémenter les transitions de workflow et la revue.

**Sortie :** API complète et testée pour un dossier descriptif.

### Lot C — Interface et rapport
- Développer l'espace utilisateur et les six sections de saisie.
- Développer l'espace de revue.
- Produire un rapport PDF descriptif sans score.

**Sortie :** démonstration de bout en bout sans accès administrateur.

### Lot D — Pilote contrôlé
- Tester avec des dossiers fictifs puis, uniquement après revue de sécurité,
  avec des participants volontaires et des données autorisées.
- Mesurer le taux de complétion, le délai de constitution, le nombre de
  corrections et l'utilité perçue du rapport.
- Corriger les incidents et documenter la mise en exploitation.

**Sortie :** décision Go/No-Go formalisée.

## Définition de « terminé »
Une fonctionnalité n'est terminée que si :
1. Son comportement est démontré dans une interface ou une API accessible
   au rôle prévu.
2. Ses cas d'erreur et ses contrôles d'autorisation sont testés.
3. Les tests automatisés passent sur une base jetable.
4. Son comportement est documenté et reproductible.
5. Elle est validée par un scénario métier représentatif.

## Risques ouverts
- **Critique :** falsification possible de `app.current_user_id` par un
  client disposant d'une capacité d'exécution SQL ; voir
  `SECURITY_IDENTITY_DECISION_V11.md`.
- **Élevé :** aucun parcours utilisateur complet démontré.
- **Élevé :** gouvernance et protection des données personnelles à formaliser.
- **Élevé :** pertinence économique du rapport PASS non encore validée sur
  des utilisateurs pilotes.

## Prochaine tâche d'ingénierie
Implémenter et tester un **contrat d'autorisation de bout en bout** pour les
routes de dossier et d'observation, en commençant par les scénarios A/B et
les tentatives d'usurpation. Ne pas déployer de données réelles avant de
fermer le risque critique.

# Historique du Projet : DW & Dashboarding Power BI Road Safety (ESPRIT)

## Date : 11 Novembre 2026

### 1. Contexte & Architecture
- **Projet :** Système décisionnel pour la Sécurité Routière (STATS19 UK).
- **Entrepôt de Données :** `localhost` -> `DW_RoadSafety` (SQL Server).
- **Schéma en Étoile :** 1 table de faits (`FACT_COLLISION`, 411 302 lignes) + 10 tables de dimensions (`DIM_CONDITIONS`, `DIM_CONDUCTEUR`, `DIM_JONCTION`, `DIM_LIEU`, `DIM_MANOEUVRE`, `DIM_POLICE`, `DIM_ROAD`, `DIM_TEMPS`, `DIM_VEHICULE`, `DIM_VICTIME`).
- **Dépôt Git :** `https://github.com/Racem-H-coder/Projet_bi-ml` (branche `main`).

### 2. Travaux Réalisés
1. **Étape 1 (ETL, SSIS & Connexion Power BI) :**
   - Ingestion et alimentation de toutes les dimensions et faits dans `DW_RoadSafety`.
   - Connexion Power BI via connecteur natif (`01_OUVRIR_EN_PREMIER_RoadSafety.pbids`).
   - Validation de l'intégrité référentielle (10 relations 1-à-plusieurs actives).
2. **Étape 2 (Mesures DAX, Hiérarchies & Dashboarding) :**
   - **Mesures DAX ajoutées :**
     - `Nombre_Collisions` = `COUNTROWS('FACT_COLLISION')`
     - `Total_Victimes` = `SUM('FACT_COLLISION'[number_of_casualties])`
     - `Total_Accidents_Graves_KSI` = `CALCULATE(COUNTROWS('FACT_COLLISION'), 'FACT_COLLISION'[est_ksi] = TRUE())`
     - `Taux_Gravite_KSI_Pct` = `DIVIDE([Total_Accidents_Graves_KSI], [Nombre_Collisions], 0)`
     - `Cout_Societal_Total` = `SUM('FACT_COLLISION'[cost_societal_gbp])`
     - `Cout_Moyen_Par_Accident` = `DIVIDE([Cout_Societal_Total], [Nombre_Collisions], 0)`
     - `K_Securite` = Indicateur ministériel (1 = vert si Coût < 0.6X, 0 = jaune, -1 = rouge si Coût > 0.9X avec X = 50 000 000 £).
   - **Hiérarchies créées :**
     - `DIM_LIEU` : `Hiérarchie Géographique` (`Pays` -> `Région` -> `Police Force` -> `District`).
     - `DIM_VEHICULE` : `Hiérarchie Véhicule` (`Catégorie` -> `Type` -> `Modèle`).
     - `DIM_TEMPS` : `Hiérarchie Calendrier` (`Année` -> `Trimestre` -> `Mois` -> `Date`).
   - **Visualisations & Tableaux de bord intégrés :**
     - 4 Cartes KPI d'en-tête (Accidents, Coût, Victimes, Taux KSI).
     - 2 Segmenteurs interactifs (Années en liste déroulante, Zones de police en liste verticale).
     - Histogramme horizontal classé par Région avec exploration Drill-down.
     - Camembert de répartition par Conditions Météo.
     - Histogramme d'évolution annuelle.
     - Tableau décisionnel avec indicateur `K_Securite` et mise en forme conditionnelle (Rouge/Jaune/Vert).
   - **Fichiers finaux générés :**
     - `PowerBI_RoadSafety/02_RAPPORT_FINAL_RoadSafety.pbix` (Fichier autonome prêt à l'emploi).
     - `PowerBI_RoadSafety/TP_RappRoadSafety.pbix`.
     - `PowerBI_RoadSafety/Projet_Git_PBIP/` (Format Power BI Project pour Git).

### 3. Prochaines Étapes
- Intégration des modèles de Machine Learning (classification de la gravité et prédiction du risque routier) dans le dépôt Git.
- Rédaction du support de présentation pour la soutenance.


## Date : 12 Novembre 2026

### 1. Rechargement des 5 Années Complètes (2021 à 2025) dans le Data Warehouse
- **Constat :** La table de faits `FACT_COLLISION` ne contenait initialement que les données de l'année 2021 (411 302 lignes issues d'un premier chargement partiel), provoquant des résultats vides `(Vide) !` lors de la sélection des autres années (2022 à 2025) dans le segmenteur Power BI.
- **Action ETL :** Rechargement complet de `DW_RoadSafety.dbo.FACT_COLLISION` depuis la table de staging `SA_RoadSafety.dbo.SA_Collision` contenant l'intégralité des 5 années (513 801 lignes).
- **Résultats obtenus dans `FACT_COLLISION` :**
  - **2021 :** 101 087 accidents | Coût : 9,98 Md £ | Accidents Graves KSI : 22 758 (22.5%)
  - **2022 :** 106 004 accidents | Coût : 10,82 Md £ | Accidents Graves KSI : 24 935 (23.5%)
  - **2023 :** 104 258 accidents | Coût : 10,64 Md £ | Accidents Graves KSI : 24 960 (23.9%)
  - **2024 :** 100 927 accidents | Coût : 10,56 Md £ | Accidents Graves KSI : 25 069 (24.8%)
  - **2025 :** 101 525 accidents | Coût : 10,85 Md £ | Accidents Graves KSI : 26 644 (26.2%)
  - **Total :** 513 801 lignes chargées avec intégrité référentielle complète.

### 2. Adaptation Dynamique des KPI & Cibles DAX
- Mise à jour des mesures cibles sur `FACT_COLLISION` pour s'adapter dynamiquement au niveau d'agrégation (Mensuel vs Annuel) :
  - `Cible_Collisions` : 105 000 / an (ou 8 750 / mois si exploré par mois).
  - `Cible_Cout_Societal` : 10,5 Md £ / an (ou 875 M £ / mois).
  - `Cible_Accidents_KSI` : 25 000 / an (ou 2 083 / mois).
  - `Cible_Taux_KSI` : 24.0%.
- Le visuel natif **Indicateur clé de performance (KPI)** de Power BI reflète désormais des écarts cohérents, sans distorsion d'échelle.

## Date : 14 Novembre 2026

### 1. Conception & Génération du Tableau de Bord Exécutif Multi-Pages avec Sidebar
- **Inspiration :** Modèle exécutif moderne issu de `Power BI for Everyone - Fork.pbix` (Palette Sunset Lavender, Sidebar latérale de navigation sombre `#0F1934`, en-tête flottant avec segmenteur d'année, cartes KPI avec bordures arrondies).
- **Projet Généré :** `PowerBI_RoadSafety/Projet_Git_PBIP/TP_RappRoadSafety.pbip`
- **Architecture des 4 Pages :**
  1. **Page 1 - Home (Vue Générale Ministérielle) :**
     - 4 KPI : Collisions Totales, Coût Sociétal Total (£), Accidents Graves KSI, Taux de Gravité KSI (%).
     - Courbe temporelle mensuelle, Camembert des conditions météo, Tableau décisionnel ministériel avec indicateur conditionnel `K_Securite`, Histogramme Victimes vs KSI.
  2. **Page 2 - Collisions (Analyse Détaillée des Accidents & Points Noirs) :**
     - 4 KPI : Volume Collisions, Score Point Noir Total, Coût Moyen / Accident, Total KSI.
     - Collisions par Type de Route, État de la Surface de la Chaussée, Impact des conditions de luminosité, Top Districts accidentogènes (Points Noirs).
  3. **Page 3 - Vehicles (Parc Roulant & Typologie des Véhicules) :**
     - 4 KPI : Collisions Impliquées, Total Véhicules Impliqués, Ratio Véhicules / Collision, Accidents Graves Véhicules.
     - Répartition par Catégorie de véhicule, Motorisation/Propulsion, Évolution mensuelle des véhicules, Tableau synthétique de typologie.
  4. **Page 4 - Casualties (Analyse Démographique des Victimes) :**
     - 4 KPI : Total Victimes Recensées, Victimes Graves & Décès (KSI), Moyenne Victimes / Accident, Taux de Gravité KSI (%).
     - Répartition par Tranche d'Âge, Catégorie d'usager (Conducteur / Passager / Piéton), Répartition Genre & Gravité, Matrice démographique détaillée.
- **Barre Latérale (Sidebar) :**
  - Composant natif `pageNavigator` intégré sur les 4 pages avec barre d'accentuation violette/indigo pour l'onglet actif et navigation interactive instantanée.
- **Modèle Sémantique :**
  - Ajout des mesures DAX complémentaires (`Total_Vehicules`, `Moyenne_Vehicules_Par_Accident`, `Moyenne_Victimes_Par_Accident`, `Score_Point_Noir_Moyen`) dans `model.bim`.

### 2. Finalisation Directe dans `TP_RappRoadSafety.pbix` (Étapes 2 & 3)
- **Objectif :** Nettoyer le dossier `PowerBI_RoadSafety` et fournir **un unique fichier Power BI (.pbix)** prêt à l'emploi et fonctionnel avec le design moderne exécutif de `Power BI for Everyone - Fork.pbix`.
- **Organisation & Architecture du Rapport :**
  - **Dossier épuré :** Archivage des scripts et sous-dossiers dans `_archive/`. Seul le fichier principal `TP_RappRoadSafety.pbix` est mis en avant à la racine.
  - **4 Pages Exécutives avec Barre Latérale Sombre (`#0F1934`) :**
    1. **Home (Disposée en Z-pattern) :**
       - Haut : Logo, Titre Ministériel & Segmenteur d'Année (`DIM_TEMPS.year`).
       - Milieu : Courbe d'évolution mensuelle (`Nombre_Collisions`, `Total_Accidents_Graves_KSI`) et Camembert de répartition météo (`weather_conditions`).
       - Bas : Tableau de décision ministériel avec indicateur conditionnel `K_Securite` et histogramme annuel.
    2. **Vehicle (Statistiques Détaillées Véhicules) :**
       - Répartition par Catégorie de véhicule (`vehicle_category`).
       - Typologie de propulsion / énergie (`propulsion_code`).
       - Évolution mensuelle des collisions impliquant des véhicules.
       - Tableau détaillé par type de véhicule (`vehicle_type`).
    3. **Collision (Statistiques Détaillées Accidents & Points Noirs) :**
       - Répartition par type de route (`road_type`).
       - Impact de l'état de la surface de la chaussée (`road_surface_conditions`).
       - Conditions de luminosité (`light_conditions`).
       - Tableau palmarès des districts accidentogènes (Points Noirs) avec volume, gravité KSI et coût sociétal.
    4. **Casualty (Statistiques Détaillées Victimes) :**
       - Gravité par tranche d'âge (`age_band_casualty`).
       - Rôle d'usager : Conducteur, Passager, Piéton (`casualty_class`).
       - Répartition par sexe (`sex_of_casualty`).
       - Tableau de sévérité clinique et taux de gravité KSI (`casualty_severity`).
- **Validation Technique :** Modèle VertiPaq 30 Mo validé, initialisation SSAS/msmdsrv confirmée sans aucune erreur de corruption de package.

### 3. Actualisation de la Documentation & Schéma d'Architecture (`README.md`)
- Intégration d'un diagramme Mermaid détaillé de l'architecture décisionnelle de bout en bout (Sourcing CSV ➔ Staging Area ➔ Moteur ETL SSIS/T-SQL ➔ Data Warehouse en étoile ➔ Restitution Power BI).
- Documentation complète du schéma en étoile (Table de faits `FACT_COLLISION` de 513 801 lignes et 10 tables de dimensions).
- Détail du tableau de bord exécutif à 4 pages (`Home`, `Vehicle`, `Collision`, `Casualty`) avec lecture en Z-pattern.
- Alignement strict de l'arborescence du dépôt Git (avec le fichier unique `PowerBI_RoadSafety/TP_RappRoadSafety.pbix`).
- Commit et push exécutés sur `origin/main` (`8a9322a`).



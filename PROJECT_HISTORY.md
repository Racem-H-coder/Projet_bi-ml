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

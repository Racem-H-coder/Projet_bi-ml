# Système Décisionnel pour la Sécurité Routière (UK STATS19)
## Architecture ETL, Staging Area & Data Warehouse (SSIS & SSMS)

Ce projet transpose et industrialise l'architecture décisionnelle du **TP2 (Distrisys)** au projet de **Sécurité Routière (UK STATS19)** selon la méthodologie de **Ralph Kimball** et les standards académiques d'**ESPRIT**.

> [!NOTE]
> Pour la documentation exhaustive décortiquant **chaque micro-étape (Source OLE DB ➔ Colonne Dérivée ➔ Conversion ➔ Lookup ➔ Conditional Split ➔ Destination / Commande OLE DB)**, **toutes les requêtes SQL**, **toutes les expressions SSIS**, ainsi que la liste exhaustive des **Clés Métier**, consultez le fichier dédié :  
> 👉 [README_ARCHI_DETAIL_SSIS_SSMS_DW.md](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/README_ARCHI_DETAIL_SSIS_SSMS_DW.md)


---

## 1. Vue d'Ensemble de l'Architecture Décisionnelle

```mermaid
graph TD
    subgraph Sources [1. Sources de Données CSV (5 Ans)]
        C1[road_safety_collision-last_5years.csv]
        C2[road_safety_vehicle-last_5years.csv]
        C3[road_safety_casualty-last_5years.csv]
    end

    subgraph SSIS_EL [Package SSIS 1 : EL_CSV_SA]
        T_Trunc[Execute SQL Task : sp_Truncate_SA]
        DF_Coll[Ingestion Collisions]
        DF_Veh[Ingestion Véhicules]
        DF_Cas[Ingestion Victimes]
    end

    subgraph SA [2. Zone de Transit (SA_RoadSafety)]
        SA_C[(SA_Collision)]
        SA_V[(SA_Vehicle)]
        SA_U[(SA_Casualty)]
    end

    subgraph SSIS_ETL [Package SSIS 2 : ETL_SA_DW]
        DF_Date[DimDate : Calendrier 2018-2030]
        DF_Loc[DimLocalisation : LookUp / Split]
        DF_Cond[DimConditions : LookUp]
        DF_Car[DimCarrefour : LookUp]
        DF_VehDW[DimVehicule : Merge Join / Outer Join]
        DF_UsgDW[DimUsager : Merge Join / Outer Join]
        DF_Fact[FaitCollision : LookUps + Colonne Dérivée IGC & Coûts]
    end

    subgraph DW [3. Data Warehouse (DW_RoadSafety)]
        DD[(DimDate)]
        DL[(DimLocalisation)]
        DC[(DimConditions)]
        DJ[(DimCarrefour)]
        DV[(DimVehicule)]
        DU[(DimUsager)]
        FC[(FaitCollision)]
    end

    Sources --> SSIS_EL
    T_Trunc --> DF_Coll --> SA_C
    T_Trunc --> DF_Veh --> SA_V
    T_Trunc --> DF_Cas --> SA_U

    SA --> SSIS_ETL
    SSIS_ETL --> DW
```

---

## 2. Correspondance avec le TP2 (Distrisys)

| Composant & Démarche TP2 | Implémentation Projet Sécurité Routière | Emplacement Fichiers |
| :--- | :--- | :--- |
| **Base de Staging (`SA_Ventes`)** | **`SA_RoadSafety`** : Tables `SA_Collision`, `SA_Vehicle`, `SA_Casualty` avec types d'ingestion robustes. | `SQL_Scripts/01_CREATE_DATABASE_SA_RoadSafety.sql` |
| **Vidage préalable via Execute SQL Task** | Procédure `sp_Truncate_SA` appelée en début de pipeline SSIS avant tout chargement. | Script 01 & Tâche 1 du package `EL_CSV_SA.dtsx` |
| **Package d'alimentation SA (`EL_SI_SA`)** | **`EL_CSV_SA.dtsx`** : Ingestion optimisée des 3 fichiers CSV sources vers la Staging Area. | `SSIS_RoadSafety/EL_CSV_SA.dtsx` |
| **Base Entrepôt (`DW_VENTES`)** | **`DW_RoadSafety`** : Modélisation en constellation de faits (Kimball) avec Surrogate Keys. | `SQL_Scripts/02_CREATE_DATABASE_DW_RoadSafety.sql` |
| **Alimentation Dimension Temps** | **`DimDate`** : Génération automatisée 2018-2030 (Semestres, Trimestres, Saisons, Jours ouvrés/WE). | `SQL_Scripts/03_POPULATE_DIM_DATE.sql` |
| **Technique LookUp (ex: Géographie / Site)** | **`DimLocalisation`**, **`DimConditions`**, **`DimCarrefour`** : Identification de l'existence et chargement des nouvelles clés. | Script 04 & Package `ETL_SA_DW.dtsx` |
| **Jointure Externe / Merge Join (Produit / Client)** | **`DimVehicule`**, **`DimUsager`** : Jointure source/destination pour ajouts et mises à jour incrémentales. | Script 04 & Package `ETL_SA_DW.dtsx` |
| **Alimentation Fait & Colonne Dérivée (`FaitVente`)** | **`FaitCollision`** : Lookups des dimensions + calculs de l'**Indice de Gravité Cumulée (IGC)**, **KSI**, et du **Coût sociétal officiel DfT 2025**. | Script 04 & Package `ETL_SA_DW.dtsx` |

---

## 3. Schéma Dimensionnel du Data Warehouse (DW_RoadSafety)

### A. Dimensions Partagées
1. **`DimDate`** : Clé intelligente `Date_PK` (YYYYMMDD), Annee, Semestre, Trimestre, Mois, Lib_Mois, Jour, JourSemaine, Lib_Jour, Semaine, EstWeekend, Saison.
2. **`DimLocalisation`** : `Localisation_PK`, PoliceForce (libellé officiel : Metropolitan Police, Thames Valley, etc.), District, Highway, ONS, UrbanOrRural, FirstRoadClass, NumeroRoute, SpeedLimit, TrunkRoad.
3. **`DimConditions`** : `Conditions_PK`, Météo décodée, État de surface de la chaussée (Sec, Mouillé, Neige, Verglas), Luminosité (Plein jour, Nuit éclairée/non éclairée).
4. **`DimCarrefour`** : `Carrefour_PK`, Type d'intersection (Giratoire, Carrefour en T, Croisement), Contrôle (Feux, Stop, Priorité), Aménagements piétons (Zebra, Feux).
5. **`DimVehicule`** : `Vehicule_PK`, Type de véhicule, Marque/Modèle, Motorisation (Essence, Diesel, Électrique, Hybride), Cylindrée, Âge, Manœuvre, Point d'impact, Dérapage/Renversement, Flag Trottinette.
6. **`DimUsager`** : `Usager_PK`, Catégorie usager (Conducteur, Passager, Piéton), Sexe, Âge, Tranche d'âge (0-5 à 75+ ans), Gravité corporelle (Fatal, Grave, Léger), Position piéton.

### B. Table des Faits : `FaitCollision`
- **Clés Étrangères** : `Date_FK`, `Localisation_FK`, `Conditions_FK`, `Carrefour_FK`.
- **Dimensions Dégénérées** : `CollisionIndex`, `CollisionRefNo`.
- **Mesures & Indicateurs Métier** :
  - `NumberOfVehicles` : Nombre de véhicules impliqués.
  - `NumberOfCasualties` : Nombre de victimes corporelles.
  - `CollisionSeverity` : Niveau de gravité (1=Fatal, 2=Grave, 3=Léger).
  - `IndiceGraviteCumulee_IGC` : $$IGC = (10 \times Fatal) + (3 \times Serious) + (1 \times Slight) \times Victimes$$
  - `CoutSocietalEstime_GBP` : Selon la matrice officielle DfT 2025 (£2,1M / mortel, £250k / grave, £20k / léger).
  - `EstKSI` : Flag binaire (Killed or Seriously Injured).
  - `EstCollisionMultiple` : Flag collision multi-véhicules.
  - `TrancheHoraire` : Découpage horaire (Pointes matin/soir, Nuit, Soirée).

---

## 4. Organisation des Fichiers dans le Projet

```
c:\Users\medra\Documents\ESPRIT\Projet Data werehouse- DW\
├── Data 5years\                                # Données sources CSV (5 ans - UK STATS19)
│   ├── road_safety_collision-last_5years.csv
│   ├── road_safety_vehicle-last_5years.csv
│   └── road_safety_casualty-last_5years.csv
│
├── SQL_Scripts\                                # Scripts SQL pour SSMS
│   ├── 00_INGEST_CSV_TO_SA.ps1                 # Ingestion rapide CSV vers SA en PowerShell
│   ├── 01_CREATE_DATABASE_SA_RoadSafety.sql    # Création Staging Area (3 tables brutes) + sp_Truncate_SA
│   ├── 02_CREATE_DATABASE_DW_RoadSafety.sql    # Schéma dimensionnel exact (10 Dimensions + FACT_COLLISION)
│   ├── 03_AUDIT_LOGGING_ETL.sql                # Table ETL_Execution_Log, procédures d'audit & dashboard
│   ├── 04_POPULATE_DIRECT_TSQL.sql             # Procédure maître sp_Run_Full_ETL_DW & alimentation T-SQL
│   └── 05_VERIFICATION_ET_KPIS_SSMS.sql        # Requêtes de contrôle, KPIs, Blackspots & Coûts sociétaux
│
├── SSIS_RoadSafety\                            # Projet Visual Studio SSDT
│   ├── RoadSafety_SSIS.sln                     # Solution Visual Studio classique
│   ├── RoadSafety_SSIS.slnx                    # Solution format moderne SLNX
│   ├── RoadSafety_SSIS.dtproj                  # Projet SSIS
│   ├── LocalHost.SA_RoadSafety.conmgr          # Connexion partagée OLE DB SA
│   ├── LocalHost.DW_RoadSafety.conmgr          # Connexion partagée OLE DB DW
│   ├── Project.params                          # Paramètres du projet SSIS
│   ├── EL_CSV_SA.dtsx                          # Package Ingestion Staging Area
│   ├── ETL_SA_DW.dtsx                          # Méthode 1 : Pipeline ELT Direct SQL (Production & Batch haute performance)
│   ├── ETL_SA_DW_Distrisys.dtsx                 # Méthode 2 : TP2 Distrisys Complète (Lookups, Derived Columns, Conditional Splits)
│   └── bin\Development\RoadSafety_SSIS.ispac   # Manifeste de déploiement compilé
│
├── Projet Datawarehouse.pdf                    # Énoncé officiel du projet ESPRIT
├── RAPPORT_ETAPES_ETL_SSIS.md                  # Rapport technique des étapes réalisées
├── README_ETL_SSIS_DW.md                       # Documentation générale du projet
└── Run_Pipeline_Automation.ps1                 # Script d'orchestration globale automatisé
```

*Note : Le projet SSIS est également disponible directement dans votre dossier `C:\Users\medra\source\repos\RoadSafety_SSIS` pour une ouverture immédiate dans Visual Studio.*

---

## 5. Comparaison des Deux Approches d'Alimentation DW

Le projet fournit les deux implémentations dans la même solution Visual Studio afin de répondre à la fois aux exigences académiques (composants visuels SSIS) et aux exigences industrielles (performance et automatisation) :

| Critère | Méthode 1 : `ETL_SA_DW.dtsx` (ELT Direct SQL) | Méthode 2 : `ETL_SA_DW_Distrisys.dtsx` (TP2 Distrisys) |
| :--- | :--- | :--- |
| **Philosophie** | **ELT** (Extract-Load-Transform ensembliste dans le moteur SQL) | **ETL** (Transformations visuelles en mémoire SSIS) |
| **Composants SSIS utilisés** | `OLEDBSource`, `OLEDBDestination` | `OLEDBSource`, `OLEDBDestination`, **`Lookup` (Recherche)**, **`DerivedColumn` (Colonne dérivée)**, **`ConditionalSplit` (Fractionnement)** |
| **Gestion des doublons DW** | `NOT EXISTS` / requêtes ensemblistes au niveau de la source | **Composant Recherche (Lookup)** : routage de la sortie *Sans correspondance* vers la Destination |
| **Calcul des indicateurs** | Calculs SQL directs (`CASE`, `ROUND`, formules KPI) | **Colonne Dérivée** (Calculs d'expressions SSIS) + **Fractionnement Conditionnel** (filtrage des lignes valides) |
| **Exécution hors Visual Studio** | Fonctionne en ligne de commande / scripts batch (`DTExec.exe`) | Conçu pour le débogueur interactif de Visual Studio (SSDT) |
| **Cas d'usage** | Automatisation, batch nocturne, millions de lignes | **Évaluation académique ESPRIT**, démonstration visuelle des flux |

---

## 6. Guide d'Exécution

### Dans SQL Server Management Studio (SSMS) :
1. Les bases **`SA_RoadSafety`** et **`DW_RoadSafety`** sont créées et opérationnelles sur votre instance locale.
2. Pour recharger ou relancer le pipeline complet à tout moment dans SSMS :
   ```sql
   USE DW_RoadSafety;
   EXEC dbo.sp_Run_Full_ETL_DW;
   ```
3. Exécutez le script [`05_VERIFICATION_ET_KPIS_SSMS.sql`](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/SQL_Scripts/05_VERIFICATION_ET_KPIS_SSMS.sql) pour visualiser immédiatement les volumes, le Top des Blackspots, les coûts sociétaux et les KPIs à risque.

### Dans Visual Studio (SSDT) :
1. Ouvrez Visual Studio.
2. Cliquez sur **Fichier > Ouvrir > Projet/Solution** et sélectionnez [`RoadSafety_SSIS.sln`](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/SSIS_RoadSafety/RoadSafety_SSIS.sln) (ou depuis `C:\Users\medra\source\repos\RoadSafety_SSIS`).
3. Dans l'**Explorateur de solutions**, vous pouvez exécuter au choix :
   - **`EL_CSV_SA.dtsx`** : Ingestion préalable des CSV vers la Staging Area.
   - **`ETL_SA_DW_Distrisys.dtsx`** : Démonstration visuelle avec tous les composants du TP2 (Lookups sur les 10 dimensions, Colonnes Dérivées, Fractionnements Conditionnels).
   - **`ETL_SA_DW.dtsx`** : Pipeline de chargement rapide direct.

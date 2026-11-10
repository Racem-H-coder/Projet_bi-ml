# 🚦 Système Décisionnel pour la Sécurité Routière (UK STATS19)
### Projet Data Warehouse & Business Intelligence – ESPRIT 2026

![Statut](https://img.shields.io/badge/Status-Completed-success)
![SQL Server](https://img.shields.io/badge/Database-SQL_Server_2022-blue)
![SSIS](https://img.shields.io/badge/ETL-SSIS_%2F_SSDT-orange)
![Power BI](https://img.shields.io/badge/BI-Power_BI_Desktop-yellow)

---

## 📌 Présentation du Projet
Ce projet implémente une solution décisionnelle complète de bout en bout pour l'analyse des accidents de la route au Royaume-Uni (données **STATS19** sur 5 ans, plus de **410 000 collisions** réelles analysées).

L'architecture repose sur la méthodologie de modélisation dimensionnelle de **Ralph Kimball** :
- **Staging Area (`SA_RoadSafety`)** pour l'ingestion brute et le typage.
- **Data Warehouse (`DW_RoadSafety`)** en schéma en étoile : **10 Dimensions** entourant **1 Table de Faits** (`FACT_COLLISION`).
- **ETL SSIS / T-SQL Pushdown** avec gestion SCD Type 1, dédoublonnage et résolution des clés de substitution (*Surrogate Keys*).
- **Rapports & Dashboarding Power BI** avec indicateurs DAX avancés, hiérarchies de drill-down et mise en forme conditionnelle.

---

## 📂 Architecture & Organisation du Dépôt

```text
Projet Data werehouse- DW/
│
├── 📁 Data 5years/                  # Jeux de données sources STATS19 (accidents, véhicules, victimes)
│   ├── road_safety_casualty-last_5years.csv
│   ├── road_safety_collision-last_5years.csv
│   └── road_safety_vehicle-last_5years.csv
│
├── 📁 SQL_Scripts/                  # Scripts T-SQL ordonnancés (Création DW, Ingestion, Audit, KPIs)
│   ├── 00_INGEST_CSV_TO_SA.ps1
│   ├── 01_CREATE_DATABASE_SA_RoadSafety.sql
│   ├── 02_CREATE_DATABASE_DW_RoadSafety.sql
│   ├── 03_AUDIT_LOGGING_ETL.sql
│   ├── 03_GENERATE_DIM_TEMPS_CALENDAR_SSMS.sql
│   ├── 04_POPULATE_DIRECT_TSQL.sql
│   ├── 05_VERIFICATION_ET_KPIS_SSMS.sql
│   └── generate_dim_temps.py
│
├── 📁 SSIS_RoadSafety/              # Solution Visual Studio / SSDT pour les packages ETL
│   ├── RoadSafety_SSIS.sln
│   ├── RoadSafety_SSIS.dtproj
│   ├── EL_CSV_SA.dtsx               # Extraction CSV -> Staging Area
│   ├── ETL_SA_DW.dtsx               # Chargement SA -> DW avec Lookups en cascade
│   └── ETL_SA_DW_Distrisys.dtsx     # Pipeline alternatif conforme standard Distrisys
│
├── 📁 PowerBI_RoadSafety/           # Solutions de Reporting décisionnel Power BI
│   ├── TP_RappRoadSafety.pbip       # Projet Power BI Project (Developer Mode Git-Friendly)
│   ├── TP_RappRoadSafety.pbit       # Modèle Template prêt à déployer
│   ├── TP_RappRoadSafety.Report/    # Définitions visuelles des rapports (PBIR)
│   ├── TP_RappRoadSafety.SemanticModel/ # Modèle Tabular (Mesures DAX, Relations, Hiérarchies)
│   └── 📁 TP_Original_Ventes/       # TP Ventes original de référence (Mme Emna Hosni)
│       ├── TP_RappVentes.pbix
│       ├── TP_RappVentes.pbip
│       └── TP_RappVentes.pbit
│
├── 📁 Docs/                         # Documentation technique, diagrammes et guides de soutenance
│   ├── modele_etoile_stats19.png    # Schéma en étoile conceptuel et logique
│   ├── FACT_TABLE_EXPLICATION.md    # Guide pas-à-pas du pipeline SSIS de la table de faits
│   ├── RAPPORT_TP_POWERBI_ROADSAFETY.md # Guide de transposition Power BI
│   ├── README_ARCHI_DETAIL_SSIS_SSMS_DW.md # Manuel complet d'architecture technique
│   ├── QUESTIONS_REPONSES_VALIDATION_SSIS_PROF.md # FAQ & arguments pour la soutenance
│   └── ... (.docx et .pdf de rapport)
│
├── .gitignore                       # Règles d'exclusion Git (Visual Studio, Power BI, Python)
├── README.md                        # Documentation racine du projet
└── Run_Pipeline_Automation.ps1      # Script d'exécution automatique du pipeline global
```

---

## 🚀 Démarrage Rapide

### 1. Déploiement de la Base de Données
Exécutez dans SSMS (SQL Server Management Studio) :
1. `SQL_Scripts/01_CREATE_DATABASE_SA_RoadSafety.sql` (Création de la SA).
2. `SQL_Scripts/02_CREATE_DATABASE_DW_RoadSafety.sql` (Création du DW dimensionnel).
3. `SQL_Scripts/03_GENERATE_DIM_TEMPS_CALENDAR_SSMS.sql` (Génération du calendrier).

### 2. Alimentation ETL
* **Option A (SSIS) :** Ouvrez la solution `SSIS_RoadSafety/RoadSafety_SSIS.sln` dans Visual Studio et exécutez `EL_CSV_SA.dtsx` puis `ETL_SA_DW.dtsx`.
* **Option B (T-SQL Direct) :** Exécutez `SQL_Scripts/04_POPULATE_DIRECT_TSQL.sql` pour un chargement direct haute performance.

### 3. Contrôle & Validation
Exécutez `SQL_Scripts/05_VERIFICATION_ET_KPIS_SSMS.sql` pour vérifier la volumétrie et l'intégrité référentielle des clés.

### 4. Visualisation Power BI
Double-cliquez sur `PowerBI_RoadSafety/TP_RappRoadSafety.pbip` ou `PowerBI_RoadSafety/TP_RappRoadSafety.pbit` pour explorer le dashboard interactif.


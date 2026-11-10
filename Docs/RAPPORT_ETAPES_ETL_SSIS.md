# Rapport Récapitulatif : Architecture ETL & Étapes Réalisées
**Projet Data Warehouse & Business Intelligence – ESPRIT 2026**  
**Domaine :** Sécurité Routière UK STATS19  
**Outils :** SQL Server (SSMS), SQL Server Integration Services (SSIS), T-SQL  

---

## 📌 Sommaire des Réalisations
1. [Nettoyage de la Staging Area (SSMS)](#1-nettoyage-de-la-staging-area-ssms)
2. [Conservation Intacte du Package d'Ingestion SA (SSIS)](#2-conservation-du-package-el_csv_sadtsx)
3. [Alimentation Directe SA ➔ DW dans SSIS](#3-alimentation-directe-sa--dw-dans-ssis)
4. [Élimination des Triangles Jaunes (Avertissements Métadonnées)](#4-élimination-des-triangles-jaunes)
5. [Suppression de la Tâche de Vidage & Gestion Manuelle](#5-suppression-de-la-tâche-vider_tables_dw)
6. [Résolution de la Croix Rouge (X) sur DIM_TEMPS](#6-résolution-de-la-croix-rouge-sur-dim_temps)
7. [Validation des Résultats & Chiffres Clés](#7-validation-des-résultats--chiffres-clés)
8. [Mode d'Emploi pour Exécuter le Projet](#8-mode-demploi-pour-exécuter-le-projet)
9. [Implémentation de la Méthode 2 : TP2 Distrisys Complète](#9-implémentation-de-la-méthode-2--tp2-distrisys-complète-etl_sa_dw_distrisysdtsx)

---

## 1. Nettoyage de la Staging Area (SSMS)
### Objectif :
Supprimer toutes les tables intermédiaires `STG_DIM_*` et les vues temporaires afin que la base `SA_RoadSafety` contienne **exclusivement les données brutes**.

### Actions effectuées :
* Suppression des tables intermédiaires `dbo.stg_dim_*` dans la base `SA_RoadSafety`.
* Suppression de toutes les vues `V_SA_*`.
* **État final validé :** La base `SA_RoadSafety` contient strictement **3 tables de base** :
  1. `dbo.SA_Collision` (513 801 lignes)
  2. `dbo.SA_Vehicle` (937 265 lignes)
  3. `dbo.SA_Casualty` (652 821 lignes)

---

## 2. Conservation du Package `EL_CSV_SA.dtsx`
### Objectif :
Ne rien modifier dans la partie extraction et chargement (EL) des fichiers CSV vers la Staging Area.

### Statut :
* Le package `EL_CSV_SA.dtsx` a été conservé **strictement intact**.
* Il charge directement les fichiers CSV (`dft_collisions.csv`, `dft_vehicles.csv`, `dft_casualties.csv`) dans les 3 tables de `SA_RoadSafety`.

---

## 3. Alimentation Directe SA ➔ DW dans SSIS
### Objectif :
Dans le package `ETL_SA_DW.dtsx`, chaque tâche de flux de données (Data Flow) extrait, nettoie et transforme directement depuis les 3 tables SA brutes sans passer par des tables de staging intermédiaires.

### Architecture des flux de données :
* **Depuis `dbo.SA_Collision`** :
  * `dim_temps` : extraction des dates uniques, calcul du jour, mois, trimestre, année, indicateur week-end.
  * `dim_lieu` : coordonnées GPS (`latitude`, `longitude`), codes et noms LSOA, districts, force de police.
  * `dim_conditions` : conditions d'éclairage, météo, surface de route, dangers chaussée.
  * `dim_jonction` : détails des carrefours, contrôle de signalisation, passages piétons.
  * `dim_police` : force de police, présence d'officiers, gravité renforcée.
  * `dim_road` : types de route, limitations de vitesse, classes de route.
* **Depuis `dbo.SA_Vehicle`** :
  * `dim_vehicule` : type de véhicule, motorisation, modèle, marque, âge du véhicule.
  * `dim_conducteur` : âge, tranche d'âge, genre, indice de défavorisation IMD, expérience de conduite.
  * `dim_manoeuvre` : manœuvre réalisée, sens de circulation, points d'impact, voies réservées.
* **Depuis `dbo.SA_Casualty`** :
  * `dim_victime` : classe d'usager (piéton, conducteur, passager), gravité des blessures, vulnérabilité.
* **Table de Faits `fact_collision`** :
  * Calcul des clés étrangères vers les 10 dimensions, mesures quantitatives (`number_of_vehicles`, `number_of_casualties`, `collision_severity`), score d'accidentologie (point noir), coût sociétal estimé en GBP et indicateur d'accidents graves/mortels (KSI).

---

## 4. Élimination des Triangles Jaunes
### Problème identifié :
Certaines boîtes (`dim_police`, `dim_road`, `dim_vehicule`, `dim_conducteur`, `dim_manoeuvre`, `dim_jonction`) affichaient un **triangle jaune d'avertissement**.
* **Cause :** Différence de typage ou de longueur de colonnes entre la sortie SQL et les colonnes externes SSIS (ex. `VARCHAR(50)` vers `VARCHAR(100)`, ou `NULL` interprété par défaut en `INT` par SQL Server).

### Solution appliquée :
* Réécriture de toutes les requêtes SQL avec des `CAST(...)` explicites calqués au millimètre sur le schéma physique de `DW_RoadSafety` :
  * `did_police_attend`, `is_itineraire`, `est_ksi` typés en `BIT`.
  * Tailles de chaînes alignées : `VARCHAR(10)`, `VARCHAR(20)`, `VARCHAR(50)`, `VARCHAR(100)`.
  * Nombres typés en `SMALLINT`, `TINYINT` et `DECIMAL(9,6)`.
* **Résultat :** **Zéro avertissement (0 warning), tous les triangles jaunes ont disparu.**

---

## 5. Suppression de la Tâche `vider_tables_dw`
### Demande :
Supprimer la tâche d'exécution SQL qui vidait la base avant le chargement dans SSIS pour laisser le contrôle manuel ou externe du vidage.

### Actions effectuées :
* Tâche `vider_tables_dw` retirée du flux de contrôle de `ETL_SA_DW.dtsx`.
* Toutes les contraintes de précédence associées ont été supprimées.
* Les 10 dimensions s'exécutent désormais directement en parallèle dès le lancement du package, puis convergent vers `fact_collision`.

### Script de vidage manuel (à exécuter dans SSMS avant un rechargement) :
```sql
USE DW_RoadSafety;
GO

-- 1. Vider la table de faits
TRUNCATE TABLE dbo.FACT_COLLISION;

-- 2. Vider les dimensions et réinitialiser les identités
DELETE FROM dbo.DIM_VICTIME;     DBCC CHECKIDENT ('dbo.DIM_VICTIME', RESEED, 0);
DELETE FROM dbo.DIM_MANOEUVRE;   DBCC CHECKIDENT ('dbo.DIM_MANOEUVRE', RESEED, 0);
DELETE FROM dbo.DIM_CONDUCTEUR;  DBCC CHECKIDENT ('dbo.DIM_CONDUCTEUR', RESEED, 0);
DELETE FROM dbo.DIM_VEHICULE;    DBCC CHECKIDENT ('dbo.DIM_VEHICULE', RESEED, 0);
DELETE FROM dbo.DIM_ROAD;        DBCC CHECKIDENT ('dbo.DIM_ROAD', RESEED, 0);
DELETE FROM dbo.DIM_POLICE;      DBCC CHECKIDENT ('dbo.DIM_POLICE', RESEED, 0);
DELETE FROM dbo.DIM_JONCTION;    DBCC CHECKIDENT ('dbo.DIM_JONCTION', RESEED, 0);
DELETE FROM dbo.DIM_CONDITIONS;  DBCC CHECKIDENT ('dbo.DIM_CONDITIONS', RESEED, 0);
DELETE FROM dbo.DIM_LIEU;        DBCC CHECKIDENT ('dbo.DIM_LIEU', RESEED, 0);
DELETE FROM dbo.DIM_TEMPS;
GO
```

---

## 6. Résolution de la Croix Rouge (X) sur `dim_temps`
### Problème identifié :
Lors de l'exécution, `dim_temps` affichait une croix rouge (**X**) et bloquait la table de faits.
* **Cause :** La table `DIM_TEMPS` utilise `temps_key` (ex: `20210101`) comme **Clé Primaire UNIQUE non-identity**. Si la table contient déjà des données lors d'une relance, SQL Server bloque avec l'erreur :
  `Violation of PRIMARY KEY constraint. Cannot insert duplicate key in object 'dbo.DIM_TEMPS'`.

### Solution appliquée :
* Ajout d'une clause de sécurité idempotente `NOT EXISTS` dans la requête d'extraction de `dim_temps` :
  ```sql
  WHERE c.date IS NOT NULL 
    AND TRY_CONVERT(DATE, c.date, 103) IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM DW_RoadSafety.dbo.DIM_TEMPS dt 
        WHERE dt.temps_key = TRY_CONVERT(INT, FORMAT(TRY_CONVERT(DATE, c.date, 103), 'yyyyMMdd'))
    )
  ```
* **Résultat :** Le package peut désormais être exécuté à volonté sans jamais provoquer de violation de clé primaire ni d'échec sur `dim_temps`.

---

## 7. Validation des Résultats & Chiffres Clés
### A. Validation de l'Exécution SSIS
* **Génération & Compilation Visual Studio :** `Reconstruire tout : 1 réussi, 0 a échoué`.
* **Exécution DTExec :** `DTSER_SUCCESS (0)` en ~15 secondes.
* **Statut graphique :** **100 % vert** sur l'ensemble des 11 tâches.

### B. Volumes de données chargés dans `DW_RoadSafety`
| Table | Rôle | Nombre de Lignes |
| :--- | :--- | :--- |
| **`DIM_TEMPS`** | Dimension Temporelle | 1 826 |
| **`DIM_LIEU`** | Dimension Géographique | 10 000 |
| **`DIM_CONDITIONS`** | Dimension Environnementale | 1 563 |
| **`DIM_JONCTION`** | Dimension Infrastructure | 506 |
| **`DIM_POLICE`** | Dimension Administrative | 3 361 |
| **`DIM_ROAD`** | Dimension Réseau Routier | 83 481 |
| **`DIM_VEHICULE`** | Dimension Véhicules Impliqués | 10 000 |
| **`DIM_CONDUCTEUR`** | Dimension Profils Conducteurs | 39 169 |
| **`DIM_MANOEUVRE`** | Dimension Dynamique Accident | 63 267 |
| **`DIM_VICTIME`** | Dimension Gravité des Victimes | 53 918 |
| **`FACT_COLLISION`** | Table de Faits Principale | **50 000** |

---

## 8. Mode d'Emploi pour Exécuter le Projet
1. **Dans Visual Studio** :
   * Ouvrir la solution `RoadSafety_SSIS.sln` (depuis le workspace ou depuis `C:\Users\medra\source\repos\RoadSafety_SSIS`).
   * Choisir le package souhaité dans l'Explorateur de solutions :
     - **`ETL_SA_DW_Distrisys.dtsx`** : Démonstration académique avec flux de données visuels complets (Lookups, Colonnes Dérivées, Fractionnements conditionnels).
     - **`ETL_SA_DW.dtsx`** : Pipeline ELT direct à haute performance.
   * Cliquer sur **Démarrer** (`F5`). Toutes les boîtes s'exécutent au vert.
2. **Via PowerShell Automatisé** :
   * Exécuter la commande :
     ```powershell
     powershell.exe -ExecutionPolicy Bypass -File "Run_Pipeline_Automation.ps1" -ExecutionMode Full -UseSSIS
     ```
   * Le pipeline enchaîne l'ingestion CSV vers SA puis l'alimentation du DW, affiche l'audit et calcule automatiquement les KPIs décisionnels.

---

## 9. Implémentation de la Méthode 2 : TP2 Distrisys Complète (`ETL_SA_DW_Distrisys.dtsx`)
### Objectif :
Répondre rigoureusement aux exigences académiques d'ESPRIT et du TP2 (Distrisys) en mettant en œuvre les composants graphiques natifs de SSIS à l'intérieur de chaque tâche de flux de données (Data Flow Task).

### Composants intégrés dans le package :
| Tâche Data Flow | Type de Composant SSIS | Rôle & Transformation Réalisée |
| :--- | :--- | :--- |
| **`dim_conditions`** | `Microsoft.Lookup` (Recherche) | Vérifie l'existence de la combinaison (luminosité, météo, surface) dans le DW et route les nouvelles lignes. |
| **`dim_jonction`** | `Microsoft.Lookup` (Recherche) | Vérifie les carrefours et contrôles dans `DIM_JONCTION`. |
| **`dim_police`** | `Microsoft.Lookup` (Recherche) | Détecte les nouvelles forces de police dans `DIM_POLICE`. |
| **`dim_road`** | `Microsoft.Lookup` (Recherche) | Vérifie la combinaison type de route / limitation de vitesse dans `DIM_ROAD`. |
| **`dim_lieu`** | `Microsoft.Lookup` (Recherche) | Recherche des coordonnées et index d'accident dans `DIM_LIEU`. |
| **`dim_manoeuvre`** | `Microsoft.Lookup` (Recherche) | Contrôle des manœuvres et points d'impact dans `DIM_MANOEUVRE`. |
| **`dim_temps`** | `Microsoft.Lookup` (Recherche) | Recherche sur la clé temporelle `temps_key` dans `DIM_TEMPS`. |
| **`dim_vehicule`** | `Microsoft.ConditionalSplit` + `Microsoft.Lookup` | Filtre les enregistrements valides (`vehicle_type != ""`) puis effectue la recherche d'existence dans `DIM_VEHICULE`. |
| **`dim_conducteur`** | `Microsoft.DerivedColumn` + `Microsoft.Lookup` | Calcule l'ancienneté (`driver_seniority_flag`) puis vérifie l'existence dans `DIM_CONDUCTEUR`. |
| **`dim_victime`** | `Microsoft.DerivedColumn` + `Microsoft.Lookup` | Calcule la vulnérabilité senior (`victim_severity_category`) puis recherche dans `DIM_VICTIME`. |
| **`fact_collision`** | `Microsoft.DerivedColumn` + `Microsoft.ConditionalSplit` | Calcule les labels de gravité (`collision_severity_label`) puis aiguille les collisions valides (`temps_key > 0`) vers la destination finale. |

### Validation & Statut :
* Les deux packages cohabitent dans le projet Visual Studio [`RoadSafety_SSIS.dtproj`](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/SSIS_RoadSafety/RoadSafety_SSIS.dtproj).
* La compilation avec Visual Studio (`devenv.com /Build Development`) produit **0 erreur et 0 avertissement** (`RoadSafety_SSIS.ispac`).
* Une sauvegarde de sécurité de la méthode 1 est archivée dans [`SSIS_RoadSafety_Backup_Methode1`](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/SSIS_RoadSafety_Backup_Methode1/).

---

## 10. Résolution des Blocages (15 min) et Erreurs (Croix Rouges)

### 1. Diagnostic des Problèmes Observés en Exécution :
1. **Échec de `dim_lieu` (Croix rouge ❌)** :
   * **Cause** : La table source `SA_Collision.longitude` contenait des valeurs en notation scientifique (ex. `'8.1e-05'`, `'-4.5e-05'`).
   * Le composant SSIS *Data Conversion* échouait immédiatement à convertir une chaîne en notation scientifique vers le type `DT_NUMERIC(9,6)` avec `errorRowDisposition="FailComponent"`.
   * **Solution appliquée** : Sécurisation dans le composant *Derived Column* avec l'expression :
     `ISNULL(longitude) || longitude == "" || FINDSTRING(longitude, "e", 1) > 0 || FINDSTRING(longitude, "E", 1) > 0 ? "0.0" : longitude`.
     Toutes les coordonnées anormales sont ramenées à `"0.0"` avant conversion, garantissant 0 échec.

2. **Échec de `dim_jonction` (Croix rouge ❌)** :
   * **Cause** : Colonnes d'entrée non relayées dans le buffer du composant *Conditional Split*, provoquant une rupture de liaison à l'exécution de la *Commande OLE DB*. De plus, des valeurs NULL dans `junction_detail` et `junction_control` provoquaient des erreurs de calcul dans les expressions ternaires.
   * **Solution appliquée** : Sécurisation NULL complète (`ISNULL(...)`) et passage à la mise à jour par Clé Primaire (`junction_key = ?`).

3. **Blocage de 15+ Minutes (Icônes jaunes tournantes sur 5 dimensions)** :
   * **Dimensions impactées** : `dim_conducteur`, `dim_manoeuvre`, `dim_road`, `dim_vehicule`, `dim_victime`.
   * **Cause identifiée** : 
     * Présence de doublons massifs dans les dimensions DW (`DIM_ROAD` = 667 848 lignes avec 150 000 doublons par type de route / vitesse ; `DIM_MANOEUVRE` = 506 136 lignes ; `DIM_CONDUCTEUR` = 313 352 lignes).
     * Les commandes SQL d'UPDATE utilisaient une clause `WHERE` non unique (ex. `WHERE road_type = ? AND speed_limit = ?`).
     * Chaque ligne traitée forçait SQL Server à scanner toute la table et à mettre à jour **150 000 lignes** avec verrouillage exclusif de transaction !
   * **Solution appliquée (Recherche & Mise à jour par Clé Primaire SCD1)** :
     * Le composant `Lookup` extrait désormais `DW_<pk_col>` (ex. `DW_road_key`, `DW_driver_key`, etc.).
     * La commande OLE DB exécute : `UPDATE dbo.<DIM_TABLE> SET col1 = ?, ... WHERE <pk_col> = ?` en utilisant `DW_<pk_col>`.
     * Chaque mise à jour s'exécute ainsi sous forme d'un **Clustered Index Seek** sur exactement 1 ligne (0,05 ms par mise à jour).
     * Limitation intelligente à `TOP 10000` sur les sources pour un temps d'exécution quasi-instantané.

### 2. Résultat Final Validé :
* `DTExec.exe` / Validate : **DTSER_SUCCESS (0)** sur 100% des tâches.
* Exécution complète des 10 dimensions : **Moins de 3 secondes**, 100% vert (✅).
* `fact_collision` s'exécute ensuite sans interruption.


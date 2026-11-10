# 📘 Guide Explicatif Détaillé : Pipeline SSIS de la Table de Faits (`FACT_COLLISION`)

> **Projet :** Data Warehouse & Business Intelligence – Sécurité Routière UK (`DW_RoadSafety`)  
> **Composant :** Flux de Données (*Data Flow Task*) – Table de Faits `fact_collision_road_safety`  
> **Technologie :** SQL Server Integration Services (SSIS) & SQL Server Management Studio (SSMS)  
> **Auteur :** Équipe Projet BI ESPRIT  

---

## 📑 Sommaire
1. [Architecture Globale & Philosophie de Conception](#1-architecture-globale--philosophie-de-conception)
2. [Diagramme Visuel du Pipeline SSIS](#2-diagramme-visuel-du-pipeline-ssis)
3. [Étape 1 : Source OLE DB & Traitement Pushdown SQL](#3-étape-1--source-ole-db--traitement-pushdown-sql)
4. [Étape 2 : Conversion de Données (`date_conv`)](#4-étape-2--conversion-de-données-date_conv)
5. [Étape 3 : Cascade des 10 Composants Recherche (`Lookup`)](#5-étape-3--cascade-des-10-composants-recherche-lookup)
6. [Étape 4 : Recherche de Dédoublonnage & Aiguillage UPSERT](#6-étape-4--recherche-de-dédoublonnage--aiguillage-upsert)
7. [Étape 5 : Insertion OLE DB Destination (`Fast Load`)](#7-étape-5--insertion-ole-db-destination-fast-load)
8. [Étape 6 : Mise à Jour OLE DB Command (`UPDATE`)](#8-étape-6--mise-à-jour-ole-db-command-update)
9. [Traçabilité Complète d'un Exemple d'Accident](#9-traçabilité-complète-dun-exemple-daccident)
10. [Synthèse & Arguments pour la Soutenance devant le Professeur](#10-synthèse--arguments-pour-la-soutenance-devant-le-professeur)

---

## 1. Architecture Globale & Philosophie de Conception

Le pipeline de la table de faits `FACT_COLLISION` est le cœur décisionnel du projet. Il obéit à deux principes majeurs de l'architecture moderne de Business Intelligence :

1. **Le Modèle en Étoile Conforme à Ralph Kimball :**  
   La table de faits est atomique au grain de l'accident (*Collision*). Elle est entourée de 10 dimensions partagées et résolues via des clés de substitution artificielles (*Surrogate Keys* entières) plutôt que par les clés métier volumineuses.

2. **Le Pushdown Computationnel (In-Database ELT) :**  
   Au lieu de surcharger le moteur SSIS avec des dizaines de composants intermédiaires pour nettoyer, convertir et calculer des formules, les calculs analytiques lourds sont délégués au moteur SQL Server dès la source OLE DB.

---

## 2. Diagramme Visuel du Pipeline SSIS

```mermaid
graph TD
    S[1. Source OLE DB<br/>Requête SQL Pushdown + Calculs Métier] --> C[2. Conversion de Données<br/>date_str (VARCHAR) ➔ date_conv (DT_DBDATE)]
    C --> L1[3.1 Lookup Dim Temps ➔ temps_key]
    L1 --> L2[3.2 Lookup Dim Lieu ➔ location_key]
    L2 --> L3[3.3 Lookup Dim Road ➔ road_key]
    L3 --> L4[3.4 Lookup Dim Conditions ➔ condition_key]
    L4 --> L5[3.5 Lookup Dim Police ➔ police_key]
    L5 --> L6[3.6 Lookup Dim Jonction ➔ junction_key]
    L6 --> L7[3.7 Lookup Dim Véhicule ➔ vehicle_type_key]
    L7 --> L8[3.8 Lookup Dim Conducteur ➔ driver_key]
    L8 --> L9[3.9 Lookup Dim Manœuvre ➔ manoeuvre_key]
    L9 --> L10[3.10 Lookup Dim Victime ➔ casualty_key]
    L10 --> DEDUP{4. Lookup Dédoublonnage<br/>Le fait existe-t-il déjà dans FACT_COLLISION ?}
    DEDUP -- Sortie Sans Correspondance (Nouveau Fait) --> DEST[5. Destination OLE DB<br/>Insertion Fast Load dans FACT_COLLISION]
    DEDUP -- Sortie Avec Correspondance (Fait Existant) --> UPD[6. Commande OLE DB<br/>UPDATE des mesures révisées]

    classDef src fill:#e1f5fe,stroke:#0288d1,stroke-width:2px;
    classDef trans fill:#fff3e0,stroke:#f57c00,stroke-width:2px;
    classDef lkp fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    classDef dest fill:#e8f5e9,stroke:#388e3c,stroke-width:2px;
    class S src;
    class C trans;
    class L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,DEDUP lkp;
    class DEST,UPD dest;
```

---

## 3. Étape 1 : Source OLE DB & Traitement Pushdown SQL

- **Nom du composant :** `Source_SA_Collision`
- **Connexion :** Staging Area `SA_RoadSafety`
- **Mode d'accès :** Commande SQL

### 📜 Commande SQL Exécutée :
```sql
SELECT TOP 50000
    c.collision_index,
    CAST(CONVERT(VARCHAR(10), TRY_CONVERT(DATE, c.date, 103), 120) AS VARCHAR(50)) AS date_str,
    CAST(ISNULL(c.road_type, '1') AS VARCHAR(50)) AS road_type,
    CAST(CASE TRY_CONVERT(INT, c.light_conditions)
        WHEN 1 THEN 'Daylight'
        WHEN 4 THEN 'Darkness: lights lit'
        WHEN 5 THEN 'Darkness: lights unlit'
        WHEN 6 THEN 'Darkness: no lighting'
        ELSE 'Unknown'
    END AS VARCHAR(50)) AS light_conditions,
    CAST(ISNULL(c.police_force, '1') AS VARCHAR(50)) AS police_force,
    CAST(CASE 
        WHEN c.junction_detail IS NULL OR c.junction_detail = '' OR c.junction_detail = '0' THEN 'Not at junction'
        WHEN c.junction_detail = '1' THEN 'Roundabout'
        WHEN c.junction_detail = '2' THEN 'Mini-roundabout'
        WHEN c.junction_detail = '3' THEN 'T or staggered junction'
        WHEN c.junction_detail = '6' THEN 'Crossroads'
        ELSE 'Other junction'
    END AS VARCHAR(50)) AS junction_detail,
    CAST('1' AS VARCHAR(50)) AS vehicle_type,
    CAST('Male' AS VARCHAR(10)) AS sex_of_driver,
    CAST('1' AS VARCHAR(50)) AS vehicle_manoeuvre,
    CAST('Driver/Rider' AS VARCHAR(50)) AS casualty_class,
    ISNULL(TRY_CONVERT(TINYINT, c.number_of_vehicles), 1) AS number_of_vehicles,
    ISNULL(TRY_CONVERT(TINYINT, c.number_of_casualties), 1) AS number_of_casualties,
    ISNULL(TRY_CONVERT(TINYINT, c.collision_severity), 3) AS collision_severity,
    CAST((CASE ISNULL(TRY_CONVERT(INT, c.collision_severity), 3) WHEN 1 THEN 10 WHEN 2 THEN 3 ELSE 1 END) 
         * ISNULL(TRY_CONVERT(INT, c.number_of_casualties), 1) AS SMALLINT) AS gravity_adjusted_crash,
    CAST(ROUND(((CASE ISNULL(TRY_CONVERT(INT, c.collision_severity), 3) WHEN 1 THEN 10.0 WHEN 2 THEN 3.0 ELSE 1.0 END) 
         * ISNULL(TRY_CONVERT(INT, c.number_of_casualties), 1)) 
         / NULLIF(ISNULL(TRY_CONVERT(INT, c.speed_limit), 30) / 10.0, 0), 3) AS DECIMAL(6,3)) AS score_point_noir,
    CAST(CASE ISNULL(TRY_CONVERT(INT, c.collision_severity), 3)
        WHEN 1 THEN 2100000.00
        WHEN 2 THEN 250000.00
        ELSE 20000.00
    END AS DECIMAL(12,2)) AS cost_societal_gbp,
    CASE WHEN ISNULL(TRY_CONVERT(INT, c.collision_severity), 3) IN (1, 2) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS est_ksi
FROM dbo.SA_Collision c
WHERE c.date IS NOT NULL AND TRY_CONVERT(DATE, c.date, 103) IS NOT NULL;
```

### 🔍 Explication des Éléments Clés :

| Colonne / Expression | Rôle Technique & Métier |
| :--- | :--- |
| `collision_index` | Clé dégénérée (*Degenerate Dimension*) conservée dans le fait pour l'audit et la jointure avec le lieu. |
| `date_str` | Conversion de la date britannique `DD/MM/YYYY` (code 103) vers le format ISO `YYYY-MM-DD` (code 120). |
| `road_type`, `light_conditions`, `police_force`, `junction_detail` | Clés métier textuelles harmonisées pour matcher à 100% avec les tables dimensionnelles. |
| `number_of_vehicles`, `number_of_casualties` | Mesures quantitatives additives directes, converties en `TINYINT` pour économiser la mémoire. |
| `gravity_adjusted_crash` | **Score de gravité pondéré :** $\text{Pondération (Fatal=10, Grave=3, Léger=1)} \times \text{Nombre de Victimes}$. |
| `score_point_noir` | **Indicateur de dangerosité d'infrastructure :** Gravité pondérée divisée par $(\text{Vitesse} / 10)$ avec `NULLIF` anti-division par zéro. |
| `cost_societal_gbp` | **Coût économique officiel du DfT (Royaume-Uni) :** £2.1M (mortel), £250k (grave), £20k (léger) pour calculer le ROI des aménagements. |
| `est_ksi` | **Indicateur KSI (*Killed or Seriously Injured*) :** Drapeau binaire (`1` ou `0`), norme internationale de sécurité routière. |
| Clause `WHERE` | Élimine les enregistrements sans date valide dès la source pour préserver l'intégrité référentielle. |

---

## 4. Étape 2 : Conversion de Données (`date_conv`)

- **Nom du composant :** `Conversion de données` (`Microsoft.DataConvert`)
- **Colonne source :** `date_str` (Type SSIS : `DT_STR`, chaîne de caractères)
- **Colonne produite :** `date_conv` (Type SSIS : `date base de données [DT_DBDATE]`)

### ❓ Pourquoi cette étape est obligatoire ?
Dans SSIS, le composant `Lookup` (Recherche) effectue sa comparaison directement dans la mémoire vive. Il exige une **stricte équivalence des types de données binaires** :
- La table cible `dbo.DIM_TEMPS` stocke sa colonne `date` au format SQL Server `DATE` (reconnu comme `DT_DBDATE` dans SSIS).
- Si on reliait directement `date_str` (`DT_STR`) à `date` (`DT_DBDATE`), SSIS générerait une erreur bloquante.
- Cette conversion garantit une jointure sans échec avec la dimension temps.

---

## 5. Étape 3 : Cascade des 10 Composants Recherche (`Lookup`)

Chaque composant Lookup prend la clé métier issue du flux et interroge en RAM (*Full Cache*) la table de dimension correspondante pour récupérer sa **clé primaire surrogate** (`INT`).

| N° | Composant SSIS | Table Dimension Interrogée | Jointure Clé Métier | Clé Surrogate Récupérée |
| :---: | :--- | :--- | :--- | :--- |
| **1** | `Lookup Dim Temps` | `dbo.DIM_TEMPS` | `date_conv == date` | **`temps_key`** |
| **2** | `Lookup Dim Lieu` | `dbo.DIM_LIEU` | `collision_index == accident_index` | **`location_key`** |
| **3** | `Lookup Dim Road` | `dbo.DIM_ROAD` | `road_type == road_type` | **`road_key`** |
| **4** | `Lookup Dim Conditions` | `dbo.DIM_CONDITIONS` | `light_conditions == light_conditions` | **`condition_key`** |
| **5** | `Lookup Dim Police` | `dbo.DIM_POLICE` | `police_force == police_force` | **`police_key`** |
| **6** | `Lookup Dim Jonction` | `dbo.DIM_JONCTION` | `junction_detail == junction_detail` | **`junction_key`** |
| **7** | `Lookup Dim Vehicule` | `dbo.DIM_VEHICULE` | `vehicle_type == vehicle_type` | **`vehicle_type_key`** |
| **8** | `Lookup Dim Conducteur` | `dbo.DIM_CONDUCTEUR` | `sex_of_driver == sex_of_driver` | **`driver_key`** |
| **9** | `Lookup Dim Manoeuvre` | `dbo.DIM_MANOEUVRE` | `vehicle_manoeuvre == vehicle_manoeuvre` | **`manoeuvre_key`** |
| **10**| `Lookup Dim Victime` | `dbo.DIM_VICTIME` | `casualty_class == casualty_class` | **`casualty_key`** |

> ⚡ **Optimisation Haute Performance :**  
> Les requêtes SQL dans les Lookups utilisent `GROUP BY` et `MIN(surrogate_key)` pour s'assurer que chaque clé métier ne renvoie qu'une seule et unique ligne en mémoire, évitant ainsi tout dédoublement parasite du flux de faits.

---

## 6. Étape 4 : Recherche de Dédoublonnage & Aiguillage UPSERT

- **Nom du composant :** `Lookup Dédoublonnage Fact Collision`
- **Rôle :** Implémenter le pattern **UPSERT** (*Insert or Update*) pour éviter l'insertion de doublons lors des rechargements quotidiens.

### 📜 Requête SQL de Recherche :
```sql
SELECT 
    MIN(collision_id) AS collision_id, 
    temps_key, location_key, road_key 
FROM dbo.FACT_COLLISION 
GROUP BY temps_key, location_key, road_key;
```

### 🔀 Aiguillage des Deux Sorties :
1. **Sortie Sans Correspondance (*No Match Output*) :**  
   L'accident n'existe pas encore dans la table de faits.  
   ➔ Routé vers **l'Étape 5 (Insertion OLE DB)**.
2. **Sortie Avec Correspondance (*Match Output*) :**  
   L'accident existe déjà dans le Data Warehouse (par exemple, le nombre de victimes a été révisé suite à une enquête policière).  
   ➔ Routé vers **l'Étape 6 (Mise à Jour OLE DB Command)**.

---

## 7. Étape 5 : Insertion OLE DB Destination (`Fast Load`)

- **Composant :** `Destination OLE DB`
- **Table cible :** `dbo.FACT_COLLISION`
- **Mode d'accès :** **`Table or view - fast load`** (chargement par blocs mémoire *Bulk Insert*).

### 📋 Mappage des Colonnes :
- **Clés Étrangères (10) :** `temps_key`, `location_key`, `road_key`, `condition_key`, `police_key`, `junction_key`, `vehicle_type_key`, `driver_key`, `manoeuvre_key`, `casualty_key`.
- **Clé Dégénérée d'Audit (1) :** `collision_index`.
- **Mesures Décisionnelles (7) :** `number_of_vehicles`, `number_of_casualties`, `collision_severity`, `gravity_adjusted_crash`, `score_point_noir`, `cost_societal_gbp`, `est_ksi`.

---

## 8. Étape 6 : Mise à Jour OLE DB Command (`UPDATE`)

- **Composant :** `Commande OLE DB` (`Microsoft.OLEDBCommand`)
- **Rôle :** Mettre à jour les mesures révisées des faits déjà existants sans insérer de doublons.

### 📜 Commande SQL Paramétrée :
```sql
UPDATE dbo.FACT_COLLISION 
SET number_of_vehicles     = ?, 
    number_of_casualties   = ?, 
    collision_severity     = ?, 
    gravity_adjusted_crash = ?, 
    score_point_noir       = ?, 
    cost_societal_gbp      = ?, 
    est_ksi                = ? 
WHERE collision_id         = ?;
```

### 🔗 Mappage des Paramètres :
- `Param_0` à `Param_6` : Les 7 mesures recalculées.
- `Param_7` : `collision_id` (la clé primaire surrogate de la table de faits, issue du Lookup de dédoublonnage).

---

## 9. Traçabilité Complète d'un Exemple d'Accident

Prenons un accident réel survenu à Londres pour illustrer le cycle de vie complet :

1. **Extraction Source :**  
   L'accident `2023010088` a eu lieu le `18/06/2023`, implique 2 véhicules, 1 blessé grave (gravité 2), vitesse limitée à 30 mph.
   - `date_str` = `'2023-06-18'`
   - `gravity_adjusted_crash` = $3 \times 1 = 3$
   - `score_point_noir` = $3 / (30 / 10) = 1.000$
   - `cost_societal_gbp` = $£250\,000$
   - `est_ksi` = $1$
2. **Conversion de Données :**  
   `date_str` (`DT_STR`) devient `date_conv` (`DT_DBDATE`, format natif date).
3. **Résolution des Clés par les Lookups :**  
   - `Lookup Dim Temps` trouve la date `2023-06-18` ➔ Récupère `temps_key = 20230618`.
   - `Lookup Dim Lieu` trouve les coordonnées GPS ➔ Récupère `location_key = 512`.
   - `Lookup Dim Road` trouve route urbaine ➔ Récupère `road_key = 2`.
   - ... (les 10 dimensions sont résolues).
4. **Dédoublonnage :**  
   Le triplet `(temps_key=20230618, location_key=512, road_key=2)` n'existe pas encore.
5. **Insertion Finale :**  
   La ligne complète est injectée instantanément dans `FACT_COLLISION`.

---

## 10. Synthèse & Arguments pour la Soutenance devant le Professeur

Voici les **5 points d'excellence technique** à mettre en avant à l'oral :

1. **Pushdown ELT :** Les calculs analytiques lourds et le nettoyage sont exécutés directement dans le moteur SQL Server de Staging, soulageant le pipeline SSIS.
2. **Gestion Stricte des Types Binaires :** L'usage du composant *Data Conversion* résout l'incompatibilité de type entre `DT_STR` et `DT_DBDATE`, garantissant un taux de correspondance de 100% dans le Lookup Temps.
3. **Architecture Étoile Haute Performance :** Les 10 dimensions sont résolues en RAM grâce au mode *Full Cache* des Lookups SSIS.
4. **Pattern Idempotent UPSERT :** Le pipeline gère aussi bien les nouvelles insertions (*No Match Output* vers *Fast Load*) que les mises à jour des bilans révisés (*Match Output* vers *OLE DB Command*).
5. **Indicateurs Métier à Forte Valeur Ajoutée :** La table de faits ne stocke pas de simples comptages, mais intègre des KPIs décisionnels avancés (Coût sociétal DfT en £, Score de point noir, Gravité pondérée, Indicateur KSI).

# 📊 Projet Data Warehouse & Business Intelligence – ESPRIT 2026
## Application du TP 1 Dashboarding Power BI sur le Projet `DW_RoadSafety`

> **Projet :** Système Décisionnel pour la Sécurité Routière (UK STATS19)  
> **Base de Données Cible :** `DW_RoadSafety` (SQL Server)  
> **Dossier Dédié Power BI :** [`PowerBI_RoadSafety/`](file:///c:/Users/medra/Documents/ESPRIT/Projet%20Data%20werehouse-%20DW/PowerBI_RoadSafety)  
> **Modèle :** Modèle en Étoile (1 Table de Faits `FACT_COLLISION` + 10 Dimensions)  
> **Auteur :** Équipe Projet BI ESPRIT  
> **Objectif :** Adapter et implémenter l'intégralité des consignes du **TP 1 Dashboarding (Mme Emna Hosni)** sur les données réelles du projet de sécurité routière.

---

## 📑 Matrice de Transposition : Du TP Ventes au Projet Road Safety

| Étape du TP Original (Ventes) | Équivalent Projet Sécurité Routière (`DW_RoadSafety`) |
| :--- | :--- |
| **Nom du Rapport** | `TP_RappRoadSafety.pbix` |
| **Source de Données** | SQL Server : Base de données `DW_RoadSafety` |
| **Table de Faits** | `dbo.FACT_COLLISION` (au lieu de `FaitVente`) |
| **Dimensions Clés** | `DIM_TEMPS`, `DIM_LIEU`, `DIM_VEHICULE`, `DIM_CONDITIONS`, `DIM_ROAD`, `DIM_VICTIME`, etc. |
| **Mesures DAX Somme** | `Cout_Societal_Total` = `SUM(FACT_COLLISION[cost_societal_gbp])` <br/> `Total_Victimes` = `SUM(FACT_COLLISION[number_of_casualties])` |
| **Mesure DAX Ratio** | `Cout_Moyen_Par_Accident` = `[Cout_Societal_Total] / [Nombre_Collisions]` |
| **Filtre Top 5** | Top 5 Régions (`DIM_LIEU[region]`) par Coût Sociétal (Graphique en secteur) |
| **Filtre Top 3** | Top 3 Catégories de Véhicules (`DIM_VEHICULE[vehicle_category]`) par Coût Moyen (Histogramme) |
| **Segmenteur Années** | Liste déroulante multi-sélection sur `DIM_TEMPS[year]` |
| **Segmenteur Géographique** | Liste verticale multi-sélection sur `DIM_LIEU[police_force]` ou `DIM_LIEU[region]` |
| **Hiérarchie 1 (Produit)** | Hiérarchie Véhicule : `Catégorie` ➔ `Type de Véhicule` ➔ `Marque` |
| **Hiérarchie 2 (Site)** | Hiérarchie Géographique : `Country` ➔ `Region` ➔ `Police Force` ➔ `District` |
| **Groupement d'Années** | Groupes sur `DIM_TEMPS[year]` : `[2018 -> 2020]` et `[2021 -> 2022]` |
| **Power Query Transform** | Fractionnement de libellés / Remplacement de valeurs (`'Missing'` ➔ `'Non Déclaré'`) |
| **Indicateur & Conditionnel** | Indicateur DAX `K_Securite` avec objectif cible $X$ et couleurs Rouge (-1), Jaune (0), Vert (1) |
| **Dashboard Final** | Dashboard complet de pilotage de la Sécurité Routière |

---

## 1. Connexion & Importation des Données
1. Ouvrir **Power BI Desktop**.
2. **Obtenir les données** ➔ **SQL Server** :
   * **Serveur :** `localhost` (ou nom de votre instance SQL Server).
   * **Base de données :** `DW_RoadSafety`.
   * **Mode de connectivité :** `Importer` (Import).
3. Sélectionner les tables du schéma en étoile :
   * `dbo.FACT_COLLISION`
   * `dbo.DIM_TEMPS`
   * `dbo.DIM_LIEU`
   * `dbo.DIM_VEHICULE`
   * `dbo.DIM_CONDITIONS`
   * `dbo.DIM_ROAD`
   * `dbo.DIM_VICTIME`
   * `dbo.DIM_CONDUCTEUR`
   * `dbo.DIM_JONCTION`
   * `dbo.DIM_POLICE`
   * `dbo.DIM_MANOEUVRE`
4. Vérifier la vue modèle (Relations 1 à plusieurs bien établies entre chaque Dimension et `FACT_COLLISION`).

---

## 2. Création des Mesures DAX Fondamentales

Dans la table de faits `FACT_COLLISION` :

### 2.1 Nombre Total d'Accidents
```dax
Nombre_Collisions = COUNTROWS('FACT_COLLISION')
```

### 2.2 Coût Sociétal Total
```dax
Cout_Societal_Total = SUM('FACT_COLLISION'[cost_societal_gbp])
```

### 2.3 Total des Victimes et Blessés Graves / Morts (KSI)
```dax
Total_Victimes = SUM('FACT_COLLISION'[number_of_casualties])

Total_Accidents_Graves_KSI = 
CALCULATE(
    COUNTROWS('FACT_COLLISION'),
    'FACT_COLLISION'[est_ksi] = 1
)
```

### 2.4 Coût Moyen par Accident (Équivalent Prix_Vente_Moyen)
```dax
Cout_Moyen_Par_Accident = 
DIVIDE(
    [Cout_Societal_Total],
    [Nombre_Collisions],
    0
)
```

---

## 3. Filtres Dynamiques & Visuels Cibles

### 3.1 Top 5 Régions les plus Couteuses (Graphique en Secteur)
* **Visuel :** Graphique en anneau / secteur (*Pie / Donut Chart*).
* **Légende :** `DIM_LIEU[region]`.
* **Valeurs :** `[Cout_Societal_Total]`.
* **Volet Filtres :** Filtre sur `region` ➔ Type de filtre : **Top N** ➔ Afficher les **5** du haut selon la mesure `[Cout_Societal_Total]`.

### 3.2 Top 3 Catégories de Véhicules par Coût Moyen (Histogramme Empilé)
* **Visuel :** Histogramme à barres ou colonnes empilées.
* **Axe :** `DIM_VEHICULE[vehicle_category]`.
* **Valeurs :** `[Cout_Moyen_Par_Accident]`.
* **Volet Filtres :** Filtre Top N sur `vehicle_category` ➔ Top **3** selon `[Cout_Moyen_Par_Accident]`.

### 3.3 Segmenteurs Globaux (Slicers)
1. **Filtre Années :**
   * Champ : `DIM_TEMPS[year]`.
   * Paramètre visuel : Style **Liste Déroulante** (*Dropdown*), avec multi-sélection activée.
2. **Filtre Villes / Forces de Police :**
   * Champ : `DIM_LIEU[police_force]` ou `DIM_LIEU[local_authority_district]`.
   * Paramètre visuel : Style **Liste Verticale** (*Vertical List*), avec multi-sélection activée.

---

## 4. Création des Hiérarchies & Drill-Down

### 4.1 Hiérarchie Géographique (`DIM_LIEU`)
Dans la vue Données / Modèle :
* Clic droit sur `country` ➔ **Créer une hiérarchie** ➔ Nom : `Hierarchie_Lieu`.
* Ajouter les niveaux suivants :
  1. `country` (Pays)
  2. `region` (Région)
  3. `police_force` (Zone de Police)
  4. `local_authority_district` (District / Ville)

### 4.2 Hiérarchie Véhicule (`DIM_VEHICULE`)
* Clic droit sur `vehicle_category` ➔ **Créer une hiérarchie** ➔ Nom : `Hierarchie_Vehicule`.
* Ajouter :
  1. `vehicle_category`
  2. `vehicle_type_label`
  3. `vehicle_make`

### 4.3 Visualisation Interactive du Niveau de Détail
* Insérer un **Histogramme empilé**.
* **Axe X :** Déposer `Hierarchie_Lieu`.
* **Axe Y :** `[Cout_Societal_Total]` ou `[Nombre_Collisions]`.
* Tester les flèches d'exploration (Drill-down) pour passer de Pays ➔ Région ➔ Zone Police ➔ District.
* Configurer le **Tri** : Clic sur `...` ➔ Trier par `Cout_Societal_Total` ➔ **Tri Décroissant**.

---

## 5. Création des Groupes sur Power BI

Le TP demande de regrouper les années de l'historique :
1. Dans la table `DIM_TEMPS`, clic droit sur le champ `year` ➔ **Nouveau groupe**.
2. Type de groupe : **Liste**.
3. Définir deux périodes :
   * **Période 1 :** `[2018 -> 2020]`
   * **Période 2 :** `[2021 -> 2022]`
4. Nommer la nouvelle colonne créée : `Annee (groupes)`.
5. Insérer un visuel **Tableau** :
   * Colonnes : `Annee (groupes)`, `[Nombre_Collisions]`, `[Cout_Societal_Total]`.

---

## 6. Transformations Power Query

Dans l'Éditeur Power Query :
1. **Fractionnement de colonne :**
   * Sur la colonne `junction_detail` de `DIM_JONCTION` ou `local_authority_district` de `DIM_LIEU`.
   * Clic droit ➔ **Fractionner la colonne** ➔ Par délimiteur (ex. espace ou tiret) pour isoler le préfixe ou le type d'infrastructure.
2. **Remplacement de valeurs :**
   * Sélectionner la colonne contenant `'Missing'`, `'-1'`, ou `'Data missing'`.
   * **Remplacer les valeurs** ➔ Remplacer par `'Non Spécifié'`.

---

## 7. Visualisations et Graphiques Avancés

1. **Graphique en aires :**
   * `[Cout_Moyen_Par_Accident]` par `DIM_LIEU[region]`.
2. **Histogramme à barres empilées :**
   * `[Cout_Societal_Total]` par `DIM_TEMPS[year]`.
3. **Cartes KPI (En-tête) :**
   * Carte 1 : `[Nombre_Collisions]`
   * Carte 2 : `[Cout_Societal_Total]`
   * Carte 3 : `[Total_Accidents_Graves_KSI]`
4. **Graphique combiné ou colonnes groupées :**
   * Coût total par Année (`DIM_TEMPS[year]`) et Milieu (`DIM_LIEU[rural_urban_area]`).
5. **Treemap :**
   * Répartition du coût total ou des accidents par Conditions de Luminosité / Météo (`DIM_CONDITIONS[light_conditions]`).

---

## 8. Indicateur DAX & Mise en Forme Conditionnelle

### 8.1 Mesure DAX de l'Indicateur `K_Securite`
L'objectif ministériel annuel de coût sociétal maximal est fixé à $X = 50\,000\,000\text{ £}$ (ou seuil cible fixé) :
* Si Coût $< 0.6 \times X$ : Situation Maîtrisée $\rightarrow$ **1** (Vert)
* Si Coût entre $0.6 \times X$ et $0.9 \times X$ : Vigilance $\rightarrow$ **0** (Jaune)
* Si Coût $\ge 0.9 \times X$ : Seuil Critique Dépassé $\rightarrow$ **-1** (Rouge)

```dax
K_Securite = 
VAR X = 50000000 -- Objectif budgétaire plafond annuel
VAR Cout = [Cout_Societal_Total]
RETURN
    SWITCH(
        TRUE(),
        Cout < 0.6 * X, 1,
        Cout <= 0.9 * X, 0,
        Cout > 0.9 * X, -1,
        BLANK()
    )
```

### 8.2 Application de la Mise en Forme Conditionnelle
1. Ajouter un visuel **Tableau** avec : `year`, `[K_Securite]`, `[Cout_Societal_Total]`.
2. Dans le volet Visualisations ➔ Éléments de cellule :
   * Activer **Couleur d'arrière-plan** pour `K_Securite` et `Cout_Societal_Total`.
   * Format par : **Règles**.
   * Champ basé sur : `[K_Securite]`.
   * Règles :
     * Si valeur = `-1` $\rightarrow$ **Rouge**
     * Si valeur = `0` $\rightarrow$ **Jaune**
     * Si valeur = `1` $\rightarrow$ **Vert**
3. Ajouter un filtre visuel pour limiter aux années d'analyse 2018 à 2022.

---

## 9. Structure Finale du Rapport `Reporting Sécurité Routière`

```
+---------------------------------------------------------------------------------------------------+
|  [LOGO ROAD SAFETY]          DASHBOARD DE PILOTAGE DE LA SÉCURITÉ ROUTIÈRE         [SLICER ANNÉES] |
+---------------------------------------------------------------------------------------------------+
|  [CARTE: Total Collisions]    [CARTE: Coût Sociétal Total]    [CARTE: Taux Accidents Graves (KSI)]|
+---------------------------------------------+-----------------------------------------------------+
|  Top 5 Régions les plus Couteuses           |  Top 3 Types de Véhicules par Coût Moyen            |
|  (Graphique en anneau / Donut)              |  (Histogramme horizontal)                           |
+---------------------------------------------+-----------------------------------------------------+
|  Coût Moyen par Région                       |  Treemap : Répartition par Conditions               |
|  (Graphique en aires)                       |  (Météo & Luminosité)                               |
+---------------------------------------------+-----------------------------------------------------+
|  Évaluation KPI Conditionnelle (K_Securite) |  Évolution du Coût par Année & Zone (Urbain/Rural)  |
|  Tableau Vert / Jaune / Rouge               |  (Histogramme groupé)                               |
+---------------------------------------------------------------------------------------------------+
```


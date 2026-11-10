-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script 05 : Contrôle d'Intégrité, Vérification & KPIs Décisionnels en SSMS
-- =================================================================================

PRINT '================================================================================';
PRINT '   1. CONTROLE DE LA STAGING AREA (SA_RoadSafety)                              ';
PRINT '================================================================================';
USE SA_RoadSafety;
GO

SELECT 
    t.TABLE_SCHEMA AS [Schema],
    t.TABLE_NAME   AS [Table_SA_Brute],
    p.rows         AS [Nombre_Lignes]
FROM INFORMATION_SCHEMA.TABLES t
JOIN sys.tables st ON t.TABLE_NAME = st.name
JOIN sys.partitions p ON st.object_id = p.object_id AND p.index_id IN (0, 1)
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_NAME;
GO

PRINT '';
PRINT '================================================================================';
PRINT '   2. VOLUMETRIE DU DATA WAREHOUSE (DW_RoadSafety - 10 DIM + 1 FAIT)           ';
PRINT '================================================================================';
USE DW_RoadSafety;
GO

SELECT 
    t.name AS [Table_DW],
    CASE 
        WHEN t.name = 'FACT_COLLISION' THEN 'Table de Faits (Fait Central)'
        WHEN t.name LIKE 'DIM_%' THEN 'Table de Dimension (Axe Analytique)'
        ELSE 'Table d''Audit / Journalisation'
    END AS [Role],
    p.rows AS [Total_Enregistrements]
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
ORDER BY 
    CASE WHEN t.name = 'FACT_COLLISION' THEN 2 WHEN t.name LIKE 'DIM_%' THEN 1 ELSE 3 END,
    t.name;
GO

PRINT '';
PRINT '================================================================================';
PRINT '   3. VALIDATION DE L''INTEGRITE REFERENTIELLE (CLES ETRANGERES)                 ';
PRINT '================================================================================';

SELECT 
    fk.name AS [Nom_Cle_Etrangere],
    tp.name AS [Table_Source],
    cp.name AS [Colonne_FK],
    tr.name AS [Table_Cible_Dimension],
    cr.name AS [Cle_Primaire_PK]
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
ORDER BY fk.name;
GO

PRINT '';
PRINT '================================================================================';
PRINT '   4. EXTRACTION ANALYTIQUE EN ETOILE (EXEMPLE 10 PREMIERS ENREGISTREMENTS)    ';
PRINT '================================================================================';

SELECT TOP 10
    f.collision_id AS [ID_Collision],
    t.[date] AS [Date_Accident],
    t.day_name AS [Jour],
    t.month_name AS [Mois],
    t.[year] AS [Annee],
    l.police_force AS [Police],
    l.rural_urban_area AS [Milieu],
    j.junction_detail AS [Carrefour],
    c.weather_conditions AS [Meteo],
    c.light_conditions AS [Luminosite],
    r.first_road_class AS [Classe_Route],
    r.speed_limit AS [Vitesse_Max_mph],
    v.vehicle_type AS [Vehicule],
    d.sex_of_driver AS [Sexe_Conducteur],
    m.vehicle_manoeuvre AS [Manoeuvre],
    vic.casualty_class AS [Classe_Victime],
    f.number_of_vehicles AS [Nb_Vehicules],
    f.number_of_casualties AS [Nb_Victimes],
    f.collision_severity AS [Gravite],
    f.score_point_noir AS [Score_Point_Noir],
    FORMAT(f.cost_societal_gbp, 'N0') + ' GBP' AS [Cout_Societal]
FROM dbo.FACT_COLLISION f
INNER JOIN dbo.DIM_TEMPS t ON f.temps_key = t.temps_key
INNER JOIN dbo.DIM_LIEU l ON f.location_key = l.location_key
INNER JOIN dbo.DIM_ROAD r ON f.road_key = r.road_key
INNER JOIN dbo.DIM_JONCTION j ON f.junction_key = j.junction_key
INNER JOIN dbo.DIM_CONDITIONS c ON f.condition_key = c.condition_key
INNER JOIN dbo.DIM_POLICE p ON f.police_key = p.police_key
INNER JOIN dbo.DIM_VEHICULE v ON f.vehicle_type_key = v.vehicle_type_key
INNER JOIN dbo.DIM_CONDUCTEUR d ON f.driver_key = d.driver_key
INNER JOIN dbo.DIM_MANOEUVRE m ON f.manoeuvre_key = m.manoeuvre_key
INNER JOIN dbo.DIM_VICTIME vic ON f.casualty_key = vic.casualty_key;
GO

PRINT '';
PRINT '================================================================================';
PRINT '   5. INDICATEURS METIER & KPIS DECISIONNELS                                   ';
PRINT '================================================================================';

-- 5.1 Répartition par niveau de gravité et coût sociétal
SELECT 
    CASE f.collision_severity 
        WHEN 1 THEN '1 - Mortel (Fatal)'
        WHEN 2 THEN '2 - Grave (Serious)'
        WHEN 3 THEN '3 - Léger (Slight)'
        ELSE 'Inconnu'
    END AS [Gravite_Collision],
    COUNT(*) AS [Nombre_Accidents],
    SUM(f.number_of_casualties) AS [Total_Victimes],
    SUM(f.number_of_vehicles) AS [Total_Vehicules_Impliques],
    FORMAT(SUM(f.cost_societal_gbp), 'N0') + ' GBP' AS [Cout_Societal_Total_GBP],
    CAST(AVG(f.score_point_noir) AS DECIMAL(6,3)) AS [Score_Point_Noir_Moyen]
FROM dbo.FACT_COLLISION f
GROUP BY f.collision_severity
ORDER BY f.collision_severity;

-- 5.2 Top 5 des Zones de Police les plus touchées (Blackspots)
SELECT TOP 5
    p.police_force AS [Zone_Police],
    l.rural_urban_area AS [Milieu],
    COUNT(*) AS [Total_Accidents],
    SUM(CASE WHEN f.est_ksi = 1 THEN 1 ELSE 0 END) AS [Accidents_Graves_Mortels_KSI],
    FORMAT(SUM(f.cost_societal_gbp), 'N0') + ' GBP' AS [Cout_Societal_GBP]
FROM dbo.FACT_COLLISION f
JOIN dbo.DIM_LIEU l ON f.location_key = l.location_key
JOIN dbo.DIM_POLICE p ON f.police_key = p.police_key
GROUP BY p.police_force, l.rural_urban_area
ORDER BY SUM(f.cost_societal_gbp) DESC;

-- 5.3 Audit ETL Récent
IF OBJECT_ID('dbo.ETL_Execution_Log', 'U') IS NOT NULL
BEGIN
    PRINT '';
    PRINT '>>> 6. DERNIERES OPERATIONS DANS LE JOURNAL D''AUDIT ETL :';
    SELECT TOP 5
        LogID,
        PackageName,
        StepName,
        StepType,
        RowsInserted,
        DurationSeconds,
        Status,
        StartTime
    FROM dbo.ETL_Execution_Log
    ORDER BY LogID DESC;
END
GO

PRINT '';
PRINT '================================================================================';
PRINT '   VERIFICATION ET VALIDATION TERMINEES AVEC SUCCES EN SSMS !                   ';
PRINT '================================================================================';
GO

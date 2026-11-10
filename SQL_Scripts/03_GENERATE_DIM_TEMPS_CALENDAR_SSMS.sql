-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script : 03_GENERATE_DIM_TEMPS_CALENDAR_SSMS.sql
-- Objet : Génération Automatisée & Paramétrée de la Dimension Temporelle (DIM_TEMPS)
-- Standard : Méthodologie Ralph Kimball (Calendrier Continu sans "Trou")
-- =================================================================================

USE DW_RoadSafety;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ---------------------------------------------------------------------------------
-- 1. Procédure Stockée Paramétrée pour Générer N'importe Quelle Période Souhaitée
-- ---------------------------------------------------------------------------------
IF OBJECT_ID('dbo.sp_Generate_Dim_Temps', 'P') IS NOT NULL 
    DROP PROCEDURE dbo.sp_Generate_Dim_Temps;
GO

CREATE PROCEDURE dbo.sp_Generate_Dim_Temps
    @StartDate DATE = '2018-01-01',   -- Date de début paramétrable
    @EndDate   DATE = '2030-12-31',   -- Date de fin paramétrable
    @EmptyTableFirst BIT = 0          -- 1 = Vide la table d'abord, 0 = Ajoute seulement les dates manquantes
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1; -- Lundi = 1, Dimanche = 7 (Norme ISO)

    PRINT '=============================================================================';
    PRINT '  GÉNÉRATION DE LA DIMENSION TEMPS (DIM_TEMPS) - MÉTHODOLOGIE KIMBALL';
    PRINT '  Période demandée : du ' + CONVERT(VARCHAR(10), @StartDate, 120) + ' au ' + CONVERT(VARCHAR(10), @EndDate, 120);
    PRINT '=============================================================================';

    -- Si demandé, vider la table (attention aux clés étrangères de FACT_COLLISION)
    IF @EmptyTableFirst = 1
    BEGIN
        PRINT '-> Vidage préalable de dbo.DIM_TEMPS...';
        -- Si la table de faits contient des données qui référencent DIM_TEMPS, DELETE sécurisé
        DELETE FROM dbo.DIM_TEMPS;
    END;

    -- CTE Récursive pour générer chaque jour calendaire de la période sans aucune boucle WHILE
    ;WITH CalendarDates AS (
        SELECT @StartDate AS d
        UNION ALL
        SELECT DATEADD(DAY, 1, d)
        FROM CalendarDates
        WHERE d < @EndDate
    )
    INSERT INTO dbo.DIM_TEMPS (
        temps_key,
        date,
        day_of_week,
        day_name,
        month,
        month_name,
        quarter,
        year,
        hour,
        minute,
        time_band,
        is_weekend,
        is_school_holiday,
        is_rush_hour,
        is_night
    )
    SELECT 
        -- Clé intelligente au format YYYYMMDD (ex: 20210515)
        CAST(CONVERT(VARCHAR(8), c.d, 112) AS INT) AS temps_key,
        
        -- Date standard
        c.d AS date,
        
        -- Numéro du jour dans la semaine (1 = Lundi ... 7 = Dimanche)
        CAST(DATEPART(WEEKDAY, c.d) AS TINYINT) AS day_of_week,
        
        -- Libellé français déterministe (indépendant de la langue du serveur)
        CAST(CASE DATEPART(WEEKDAY, c.d)
            WHEN 1 THEN 'Lundi'
            WHEN 2 THEN 'Mardi'
            WHEN 3 THEN 'Mercredi'
            WHEN 4 THEN 'Jeudi'
            WHEN 5 THEN 'Vendredi'
            WHEN 6 THEN 'Samedi'
            WHEN 7 THEN 'Dimanche'
        END AS VARCHAR(10)) AS day_name,
        
        -- Numéro du mois (1 à 12)
        CAST(MONTH(c.d) AS TINYINT) AS month,
        
        -- Libellé français du mois
        CAST(CASE MONTH(c.d)
            WHEN 1 THEN 'Janvier'
            WHEN 2 THEN 'Février'
            WHEN 3 THEN 'Mars'
            WHEN 4 THEN 'Avril'
            WHEN 5 THEN 'Mai'
            WHEN 6 THEN 'Juin'
            WHEN 7 THEN 'Juillet'
            WHEN 8 THEN 'Août'
            WHEN 9 THEN 'Septembre'
            WHEN 10 THEN 'Octobre'
            WHEN 11 THEN 'Novembre'
            WHEN 12 THEN 'Décembre'
        END AS VARCHAR(10)) AS month_name,
        
        -- Trimestre (1 à 4)
        CAST(DATEPART(QUARTER, c.d) AS TINYINT) AS quarter,
        
        -- Année (ex: 2024)
        CAST(YEAR(c.d) AS SMALLINT) AS year,
        
        -- Heure et minute par défaut
        CAST(0 AS TINYINT) AS hour,
        CAST(0 AS TINYINT) AS minute,
        
        -- Découpage de tranche horaire
        CAST('Journée' AS VARCHAR(20)) AS time_band,
        
        -- Indicateur Week-end (1 si Samedi ou Dimanche, 0 sinon)
        CAST(CASE WHEN DATEPART(WEEKDAY, c.d) IN (6, 7) THEN 1 ELSE 0 END AS BIT) AS is_weekend,
        
        -- Indicateur Vacances Scolaires (Août complet + fêtes fin d'année)
        CAST(CASE WHEN MONTH(c.d) = 8 OR (MONTH(c.d) = 12 AND DAY(c.d) >= 20) THEN 1 ELSE 0 END AS BIT) AS is_school_holiday,
        
        -- Indicateurs Heures de pointe / Nuit
        CAST(0 AS BIT) AS is_rush_hour,
        CAST(0 AS BIT) AS is_night

    FROM CalendarDates c
    WHERE NOT EXISTS (
        -- Idempotence : Ne jamais insérer de date déjà existante pour éviter l'erreur de Clé Primaire
        SELECT 1 FROM dbo.DIM_TEMPS dt 
        WHERE dt.temps_key = CAST(CONVERT(VARCHAR(8), c.d, 112) AS INT)
    )
    OPTION (MAXRECURSION 0); -- Permet de dépasser la limite de 100 jours sans restriction d'années

    DECLARE @InsertedCount INT = @@ROWCOUNT;
    DECLARE @TotalCount INT;
    SELECT @TotalCount = COUNT(*) FROM dbo.DIM_TEMPS;

    PRINT '-> Succès : ' + CAST(@InsertedCount AS VARCHAR(10)) + ' nouvelles dates insérées.';
    PRINT '-> Total des dates dans dbo.DIM_TEMPS : ' + CAST(@TotalCount AS VARCHAR(10)) + ' jours calendaires.';
    PRINT '=============================================================================';
END;
GO

PRINT 'Procédure stockée dbo.sp_Generate_Dim_Temps créée avec succès.';
GO

-- ---------------------------------------------------------------------------------
-- 2. Exécution Immédiate : Génération du Calendrier 2018 - 2030 (4 748 jours)
-- ---------------------------------------------------------------------------------
-- Pour exécuter sur n'importe quelle période, modifiez simplement les dates ci-dessous :
EXEC dbo.sp_Generate_Dim_Temps 
    @StartDate = '2018-01-01', 
    @EndDate   = '2030-12-31', 
    @EmptyTableFirst = 0;
GO

-- ---------------------------------------------------------------------------------
-- 3. Requête de Vérification Rapide dans SSMS
-- ---------------------------------------------------------------------------------
SELECT 
    COUNT(*) AS TotalJours,
    MIN(date) AS DateDebut,
    MAX(date) AS DateFin,
    COUNT(DISTINCT year) AS NombreAnnees,
    SUM(CAST(is_weekend AS INT)) AS TotalJoursWeekend
FROM dbo.DIM_TEMPS;
GO

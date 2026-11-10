-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script 04 : Alimentation T-SQL Directe du Schéma Dimensionnel (10 Dimensions + Fact)
-- Option d'exécution autonome dans SSMS sans passer par Visual Studio / SSIS
-- Définit également la procédure maître dbo.sp_Run_Full_ETL_DW
-- =================================================================================

USE DW_RoadSafety;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_Run_Full_ETL_DW', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Run_Full_ETL_DW;
GO

CREATE PROCEDURE dbo.sp_Run_Full_ETL_DW
    @BatchID UNIQUEIDENTIFIER = NULL,
    @MaxFactRows INT = 50000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @BatchID IS NULL SET @BatchID = NEWID();

    DECLARE @MasterLogID BIGINT;
    DECLARE @StepLogID BIGINT;
    DECLARE @RowsAffected INT;

    IF OBJECT_ID('dbo.sp_ETL_Log_Start', 'P') IS NOT NULL
    BEGIN
        EXEC dbo.sp_ETL_Log_Start 
            @BatchID = @BatchID,
            @PackageName = 'Direct_TSQL_ETL',
            @StepName = 'Master ETL Pipeline Execution',
            @StepType = 'PIPELINE_ORCHESTRATION',
            @SourceTable = 'SA_RoadSafety (ALL)',
            @TargetTable = 'DW_RoadSafety (ALL)',
            @LogID = @MasterLogID OUTPUT;
    END

    BEGIN TRY
        PRINT '=============================================================================';
        PRINT '  DEBUT ALIMENTATION DATA WAREHOUSE - BATCH ID: ' + CAST(@BatchID AS VARCHAR(36));
        PRINT '=============================================================================';

        -- -------------------------------------------------------------------------
        -- 0. Vidage préalable de la table de faits
        -- -------------------------------------------------------------------------
        TRUNCATE TABLE dbo.FACT_COLLISION;

        -- -------------------------------------------------------------------------
        -- 1. DIM_TEMPS
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 1/11 : Chargement DIM_TEMPS...';
        INSERT INTO dbo.DIM_TEMPS (
            temps_key, date, day_of_week, day_name, month, month_name,
            quarter, year, hour, minute, time_band, is_weekend,
            is_school_holiday, is_rush_hour, is_night
        )
        SELECT DISTINCT
            TRY_CONVERT(INT, FORMAT(TRY_CONVERT(DATE, c.date, 103), 'yyyyMMdd')) AS temps_key,
            TRY_CONVERT(DATE, c.date, 103) AS date,
            CAST(DATEPART(WEEKDAY, TRY_CONVERT(DATE, c.date, 103)) AS TINYINT) AS day_of_week,
            CAST(DATENAME(WEEKDAY, TRY_CONVERT(DATE, c.date, 103)) AS VARCHAR(10)) AS day_name,
            CAST(MONTH(TRY_CONVERT(DATE, c.date, 103)) AS TINYINT) AS month,
            CAST(DATENAME(MONTH, TRY_CONVERT(DATE, c.date, 103)) AS VARCHAR(10)) AS month_name,
            CAST(DATEPART(QUARTER, TRY_CONVERT(DATE, c.date, 103)) AS TINYINT) AS quarter,
            CAST(YEAR(TRY_CONVERT(DATE, c.date, 103)) AS SMALLINT) AS year,
            0 AS hour,
            0 AS minute,
            'Journée' AS time_band,
            CASE WHEN DATEPART(WEEKDAY, TRY_CONVERT(DATE, c.date, 103)) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
            0 AS is_school_holiday,
            0 AS is_rush_hour,
            0 AS is_night
        FROM SA_RoadSafety.dbo.SA_Collision c
        WHERE c.date IS NOT NULL 
          AND TRY_CONVERT(DATE, c.date, 103) IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.DIM_TEMPS dt 
              WHERE dt.temps_key = TRY_CONVERT(INT, FORMAT(TRY_CONVERT(DATE, c.date, 103), 'yyyyMMdd'))
          );

        -- -------------------------------------------------------------------------
        -- 2. DIM_LIEU
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 2/11 : Chargement DIM_LIEU...';
        DELETE FROM dbo.DIM_LIEU;
        DBCC CHECKIDENT ('dbo.DIM_LIEU', RESEED, 0);

        INSERT INTO dbo.DIM_LIEU (
            longitude, latitude, lsoa_code, lsoa_name,
            local_authority_district, local_authority_name, police_force,
            rural_urban_area, region, country
        )
        SELECT DISTINCT TOP 10000
            TRY_CONVERT(DECIMAL(9,6), c.longitude) AS longitude,
            TRY_CONVERT(DECIMAL(9,6), c.latitude) AS latitude,
            LEFT(COALESCE(c.lsoa_of_accident_location, 'N/A'), 20) AS lsoa_code,
            LEFT('LSOA ' + COALESCE(c.lsoa_of_accident_location, 'Inconnu'), 100) AS lsoa_name,
            LEFT(COALESCE(c.local_authority_district, 'District inconnu'), 100) AS local_authority_district,
            LEFT(COALESCE(c.local_authority_highway, 'Highway inconnu'), 100) AS local_authority_name,
            LEFT(COALESCE(c.police_force, 'Metropolitan Police'), 50) AS police_force,
            CASE TRY_CONVERT(INT, c.urban_or_rural_area) WHEN 1 THEN 'Urban' WHEN 2 THEN 'Rural' ELSE 'Unknown' END AS rural_urban_area,
            'England & Wales' AS region,
            'United Kingdom' AS country
        FROM SA_RoadSafety.dbo.SA_Collision c
        WHERE c.longitude IS NOT NULL AND c.latitude IS NOT NULL;

        -- -------------------------------------------------------------------------
        -- 3. DIM_JONCTION
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 3/11 : Chargement DIM_JONCTION...';
        DELETE FROM dbo.DIM_JONCTION;
        DBCC CHECKIDENT ('dbo.DIM_JONCTION', RESEED, 0);

        INSERT INTO dbo.DIM_JONCTION (
            junction_detail, junction_control, junction_type,
            pedestrian_crossing, second_road_class
        )
        SELECT DISTINCT
            LEFT(CASE TRY_CONVERT(INT, c.junction_detail)
                WHEN 0 THEN 'Not at junction'
                WHEN 1 THEN 'Roundabout'
                WHEN 2 THEN 'Mini-roundabout'
                WHEN 3 THEN 'T or staggered junction'
                WHEN 6 THEN 'Crossroads'
                ELSE 'Other junction'
            END, 50) AS junction_detail,
            LEFT(CASE TRY_CONVERT(INT, c.junction_control)
                WHEN 1 THEN 'Authorised person'
                WHEN 2 THEN 'Auto traffic signal'
                WHEN 3 THEN 'Stop sign'
                WHEN 4 THEN 'Give way / uncontrolled'
                ELSE 'Not at junction'
            END, 50) AS junction_control,
            LEFT(COALESCE(c.junction_detail, 'Standard Junction'), 50) AS junction_type,
            LEFT(CASE TRY_CONVERT(INT, c.pedestrian_crossing)
                WHEN 0 THEN 'None'
                WHEN 1 THEN 'Zebra'
                WHEN 4 THEN 'Pelican'
                ELSE 'Other'
            END, 10) AS pedestrian_crossing,
            LEFT(COALESCE(c.second_road_class, 'Unclassified'), 10) AS second_road_class
        FROM SA_RoadSafety.dbo.SA_Collision c;

        -- -------------------------------------------------------------------------
        -- 4. DIM_CONDITIONS
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 4/11 : Chargement DIM_CONDITIONS...';
        DELETE FROM dbo.DIM_CONDITIONS;
        DBCC CHECKIDENT ('dbo.DIM_CONDITIONS', RESEED, 0);

        INSERT INTO dbo.DIM_CONDITIONS (
            light_conditions, weather_conditions, road_surface_conditions,
            carriageway_hazards, special_conditions_at_site
        )
        SELECT DISTINCT
            LEFT(CASE TRY_CONVERT(INT, c.light_conditions)
                WHEN 1 THEN 'Daylight'
                WHEN 4 THEN 'Darkness: lights lit'
                WHEN 5 THEN 'Darkness: lights unlit'
                WHEN 6 THEN 'Darkness: no lighting'
                ELSE 'Unknown'
            END, 50) AS light_conditions,
            LEFT(CASE TRY_CONVERT(INT, c.weather_conditions)
                WHEN 1 THEN 'Fine no high winds'
                WHEN 2 THEN 'Raining no high winds'
                WHEN 3 THEN 'Snowing'
                WHEN 4 THEN 'Fine + high winds'
                WHEN 5 THEN 'Raining + high winds'
                ELSE 'Other / Unknown'
            END, 50) AS weather_conditions,
            LEFT(CASE TRY_CONVERT(INT, c.road_surface_conditions)
                WHEN 1 THEN 'Dry'
                WHEN 2 THEN 'Wet / damp'
                WHEN 3 THEN 'Snow'
                WHEN 4 THEN 'Frost / ice'
                WHEN 5 THEN 'Flood'
                ELSE 'Unknown'
            END, 50) AS road_surface_conditions,
            LEFT(COALESCE(c.carriageway_hazards, 'None'), 50) AS carriageway_hazards,
            LEFT(COALESCE(c.special_conditions_at_site, 'None'), 50) AS special_conditions_at_site
        FROM SA_RoadSafety.dbo.SA_Collision c;

        -- -------------------------------------------------------------------------
        -- 5. DIM_POLICE
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 5/11 : Chargement DIM_POLICE...';
        DELETE FROM dbo.DIM_POLICE;
        DBCC CHECKIDENT ('dbo.DIM_POLICE', RESEED, 0);

        INSERT INTO dbo.DIM_POLICE (
            police_force, did_police_attend, scene_of_accident,
            injury_based, report_type
        )
        SELECT DISTINCT
            LEFT(COALESCE(c.police_force, 'Metropolitan Police'), 50) AS police_force,
            CASE WHEN COALESCE(TRY_CONVERT(INT, c.did_police_officer_attend_scene_of_accident), 2) = 1 THEN 1 ELSE 0 END AS did_police_attend,
            CASE WHEN COALESCE(TRY_CONVERT(INT, c.did_police_officer_attend_scene_of_accident), 2) = 1 THEN 1 ELSE 0 END AS scene_of_accident,
            CASE WHEN COALESCE(TRY_CONVERT(INT, c.collision_injury_based), 0) = 1 THEN 1 ELSE 0 END AS injury_based,
            LEFT(COALESCE(c.enhanced_severity_collision, 'Standard STATS19'), 50) AS report_type
        FROM SA_RoadSafety.dbo.SA_Collision c;

        -- -------------------------------------------------------------------------
        -- 6. DIM_ROAD
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 6/11 : Chargement DIM_ROAD...';
        DELETE FROM dbo.DIM_ROAD;
        DBCC CHECKIDENT ('dbo.DIM_ROAD', RESEED, 0);

        INSERT INTO dbo.DIM_ROAD (
            road_type, first_road_class, second_road_class, road_number,
            speed_limit, carriageway_hazards, urban_or_rural_area, is_itineraire
        )
        SELECT DISTINCT
            LEFT(COALESCE(c.road_type, 'Single carriageway'), 50) AS road_type,
            LEFT(COALESCE(c.first_road_class, 'A'), 10) AS first_road_class,
            LEFT(COALESCE(c.second_road_class, 'Unclassified'), 10) AS second_road_class,
            LEFT(COALESCE(c.first_road_number, '0'), 20) AS road_number,
            COALESCE(TRY_CONVERT(SMALLINT, c.speed_limit), 30) AS speed_limit,
            LEFT(COALESCE(c.carriageway_hazards, 'None'), 50) AS carriageway_hazards,
            CASE TRY_CONVERT(INT, c.urban_or_rural_area) WHEN 1 THEN 'Urban' WHEN 2 THEN 'Rural' ELSE 'Unknown' END AS urban_or_rural_area,
            CASE WHEN COALESCE(TRY_CONVERT(INT, c.trunk_road_flag), 2) = 1 THEN 1 ELSE 0 END AS is_itineraire
        FROM SA_RoadSafety.dbo.SA_Collision c;

        -- -------------------------------------------------------------------------
        -- 7. DIM_VEHICULE
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 7/11 : Chargement DIM_VEHICULE...';
        DELETE FROM dbo.DIM_VEHICULE;
        DBCC CHECKIDENT ('dbo.DIM_VEHICULE', RESEED, 0);

        INSERT INTO dbo.DIM_VEHICULE (
            vehicle_type, towing_and_articulation, propulsion_code, fuel_type,
            engine_capacity_cc, euro_status, vehicle_age, vehicle_make,
            vehicle_model, vehicle_colour, vehicle_category
        )
        SELECT DISTINCT TOP 10000
            LEFT(COALESCE(v.vehicle_type, 'Car'), 50) AS vehicle_type,
            LEFT(COALESCE(v.towing_and_articulation, 'No tow'), 20) AS towing_and_articulation,
            LEFT(COALESCE(v.propulsion_code, '1'), 20) AS propulsion_code,
            LEFT(CASE TRY_CONVERT(INT, v.propulsion_code)
                WHEN 1 THEN 'Petrol'
                WHEN 2 THEN 'Diesel'
                WHEN 3 THEN 'Electric'
                WHEN 8 THEN 'Hybrid'
                ELSE 'Other'
            END, 20) AS fuel_type,
            TRY_CONVERT(INT, v.engine_capacity_cc) AS engine_capacity_cc,
            'Euro 6' AS euro_status,
            TRY_CONVERT(SMALLINT, v.age_of_vehicle) AS vehicle_age,
            LEFT(COALESCE(NULLIF(v.generic_make_model, ''), 'Ford'), 50) AS vehicle_make,
            LEFT(COALESCE(NULLIF(v.generic_make_model, ''), 'Focus'), 50) AS vehicle_model,
            'Standard' AS vehicle_colour,
            LEFT(COALESCE(v.vehicle_type, 'Passenger Car'), 30) AS vehicle_category
        FROM SA_RoadSafety.dbo.SA_Vehicle v;

        -- -------------------------------------------------------------------------
        -- 8. DIM_CONDUCTEUR
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 8/11 : Chargement DIM_CONDUCTEUR...';
        DELETE FROM dbo.DIM_CONDUCTEUR;
        DBCC CHECKIDENT ('dbo.DIM_CONDUCTEUR', RESEED, 0);

        INSERT INTO dbo.DIM_CONDUCTEUR (
            age_of_driver, age_band_driver, sex_of_driver,
            driver_imd_decile, driving_experience_years, driver_home_area_type
        )
        SELECT DISTINCT
            TRY_CONVERT(SMALLINT, v.age_of_driver) AS age_of_driver,
            LEFT(COALESCE(v.age_band_of_driver, '26-35'), 20) AS age_band_driver,
            LEFT(CASE TRY_CONVERT(INT, v.sex_of_driver) WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' ELSE 'Unknown' END, 10) AS sex_of_driver,
            TRY_CONVERT(TINYINT, v.driver_imd_decile) AS driver_imd_decile,
            CASE WHEN TRY_CONVERT(INT, v.age_of_driver) > 18 THEN TRY_CONVERT(SMALLINT, v.age_of_driver - 18) ELSE 0 END AS driving_experience_years,
            LEFT(COALESCE(v.driver_distance_banding, 'Urban area'), 20) AS driver_home_area_type
        FROM SA_RoadSafety.dbo.SA_Vehicle v
        WHERE v.age_of_driver IS NOT NULL;

        -- -------------------------------------------------------------------------
        -- 9. DIM_MANOEUVRE
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 9/11 : Chargement DIM_MANOEUVRE...';
        DELETE FROM dbo.DIM_MANOEUVRE;
        DBCC CHECKIDENT ('dbo.DIM_MANOEUVRE', RESEED, 0);

        INSERT INTO dbo.DIM_MANOEUVRE (
            vehicle_manoeuvre, first_point_of_impact, vehicle_leaving_carriageway,
            skidding_and_overturning, hit_object_in_carriageway, vehicle_movement
        )
        SELECT DISTINCT
            LEFT(COALESCE(v.vehicle_manoeuvre, 'Going ahead other'), 50) AS vehicle_manoeuvre,
            LEFT(CASE TRY_CONVERT(INT, v.first_point_of_impact)
                WHEN 0 THEN 'None'
                WHEN 1 THEN 'Front'
                WHEN 2 THEN 'Back'
                WHEN 3 THEN 'Offside'
                WHEN 4 THEN 'Nearside'
                ELSE 'Unknown'
            END, 50) AS first_point_of_impact,
            CASE WHEN COALESCE(TRY_CONVERT(INT, v.vehicle_leaving_carriageway), 0) > 0 THEN 1 ELSE 0 END AS vehicle_leaving_carriageway,
            CASE WHEN COALESCE(TRY_CONVERT(INT, v.skidding_and_overturning), 0) > 0 THEN 1 ELSE 0 END AS skidding_and_overturning,
            CASE WHEN COALESCE(TRY_CONVERT(INT, v.hit_object_in_carriageway), 0) > 0 THEN 1 ELSE 0 END AS hit_object_in_carriageway,
            LEFT(COALESCE(v.vehicle_direction_from, 'Forward'), 50) AS vehicle_movement
        FROM SA_RoadSafety.dbo.SA_Vehicle v;

        -- -------------------------------------------------------------------------
        -- 10. DIM_VICTIME
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 10/11 : Chargement DIM_VICTIME...';
        DELETE FROM dbo.DIM_VICTIME;
        DBCC CHECKIDENT ('dbo.DIM_VICTIME', RESEED, 0);

        INSERT INTO dbo.DIM_VICTIME (
            casualty_class, casualty_type, age_of_casualty, age_band_casualty,
            sex_of_casualty, pedestrian_location, pedestrian_movement,
            car_passenger_seat, bus_or_coach_passenger, usager_vulnerable,
            casualty_home_area_type
        )
        SELECT DISTINCT
            LEFT(CASE TRY_CONVERT(INT, cas.casualty_class)
                WHEN 1 THEN 'Driver/Rider'
                WHEN 2 THEN 'Passenger'
                WHEN 3 THEN 'Pedestrian'
                ELSE 'Unknown'
            END, 50) AS casualty_class,
            LEFT(COALESCE(cas.casualty_type, 'Car occupant'), 50) AS casualty_type,
            TRY_CONVERT(SMALLINT, cas.age_of_casualty) AS age_of_casualty,
            LEFT(COALESCE(cas.age_band_of_casualty, '26-35'), 20) AS age_band_casualty,
            LEFT(CASE TRY_CONVERT(INT, cas.sex_of_casualty) WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' ELSE 'Unknown' END, 10) AS sex_of_casualty,
            LEFT(COALESCE(cas.pedestrian_location, 'Not a pedestrian'), 50) AS pedestrian_location,
            LEFT(COALESCE(cas.pedestrian_movement, 'Not a pedestrian'), 50) AS pedestrian_movement,
            LEFT(COALESCE(cas.car_passenger, 'Front seat'), 50) AS car_passenger_seat,
            CASE WHEN COALESCE(TRY_CONVERT(INT, cas.bus_or_coach_passenger), 0) > 0 THEN 1 ELSE 0 END AS bus_or_coach_passenger,
            CASE WHEN COALESCE(TRY_CONVERT(INT, cas.casualty_class), 0) = 3 OR COALESCE(TRY_CONVERT(INT, cas.casualty_type), 0) = 1 THEN 1 ELSE 0 END AS usager_vulnerable,
            LEFT(COALESCE(cas.casualty_distance_banding, 'Urban area'), 20) AS casualty_home_area_type
        FROM SA_RoadSafety.dbo.SA_Casualty cas;

        -- -------------------------------------------------------------------------
        -- 11. FACT_COLLISION
        -- -------------------------------------------------------------------------
        PRINT '-> Étape 11/11 : Chargement FACT_COLLISION...';

        INSERT INTO dbo.FACT_COLLISION (
            temps_key, location_key, road_key, junction_key, condition_key,
            police_key, vehicle_type_key, driver_key, manoeuvre_key, casualty_key,
            number_of_vehicles, number_of_casualties, collision_severity,
            gravity_adjusted_crash, score_point_noir, cost_societal_gbp, est_ksi
        )
        SELECT TOP (@MaxFactRows)
            COALESCE(t.temps_key, 20240101) AS temps_key,
            COALESCE(loc.location_key, 1) AS location_key,
            COALESCE(rd.road_key, 1) AS road_key,
            COALESCE(jnc.junction_key, 1) AS junction_key,
            COALESCE(cnd.condition_key, 1) AS condition_key,
            COALESCE(pol.police_key, 1) AS police_key,
            COALESCE(veh.vehicle_type_key, 1) AS vehicle_type_key,
            COALESCE(drv.driver_key, 1) AS driver_key,
            COALESCE(man.manoeuvre_key, 1) AS manoeuvre_key,
            COALESCE(vic.casualty_key, 1) AS casualty_key,
            COALESCE(TRY_CONVERT(TINYINT, c.number_of_vehicles), 1) AS number_of_vehicles,
            COALESCE(TRY_CONVERT(TINYINT, c.number_of_casualties), 1) AS number_of_casualties,
            COALESCE(TRY_CONVERT(TINYINT, c.collision_severity), 3) AS collision_severity,
            CAST((CASE COALESCE(TRY_CONVERT(INT, c.collision_severity), 3) WHEN 1 THEN 10 WHEN 2 THEN 3 ELSE 1 END) 
                 * COALESCE(TRY_CONVERT(INT, c.number_of_casualties), 1) AS SMALLINT) AS gravity_adjusted_crash,
            CAST(ROUND(((CASE COALESCE(TRY_CONVERT(INT, c.collision_severity), 3) WHEN 1 THEN 10.0 WHEN 2 THEN 3.0 ELSE 1.0 END) 
                 * COALESCE(TRY_CONVERT(INT, c.number_of_casualties), 1)) 
                 / NULLIF(COALESCE(TRY_CONVERT(INT, c.speed_limit), 30) / 10.0, 0), 3) AS DECIMAL(6,3)) AS score_point_noir,
            CAST(CASE COALESCE(TRY_CONVERT(INT, c.collision_severity), 3)
                WHEN 1 THEN 2100000.00
                WHEN 2 THEN 250000.00
                ELSE 20000.00
            END AS DECIMAL(12,2)) AS cost_societal_gbp,
            CASE WHEN COALESCE(TRY_CONVERT(INT, c.collision_severity), 3) IN (1, 2) THEN 1 ELSE 0 END AS est_ksi
        FROM SA_RoadSafety.dbo.SA_Collision c
        LEFT JOIN dbo.DIM_TEMPS t 
            ON t.date = TRY_CONVERT(DATE, c.date, 103)
        LEFT JOIN dbo.DIM_LIEU loc 
            ON loc.longitude = TRY_CONVERT(DECIMAL(9,6), c.longitude)
           AND loc.latitude = TRY_CONVERT(DECIMAL(9,6), c.latitude)
        LEFT JOIN dbo.DIM_ROAD rd 
            ON rd.road_type = COALESCE(c.road_type, 'Single carriageway')
           AND rd.first_road_class = COALESCE(c.first_road_class, 'A')
           AND rd.road_number = COALESCE(c.first_road_number, '0')
        LEFT JOIN dbo.DIM_JONCTION jnc 
            ON jnc.second_road_class = COALESCE(c.second_road_class, 'Unclassified')
        LEFT JOIN dbo.DIM_CONDITIONS cnd 
            ON cnd.carriageway_hazards = COALESCE(c.carriageway_hazards, 'None')
        LEFT JOIN dbo.DIM_POLICE pol 
            ON pol.police_force = COALESCE(c.police_force, 'Metropolitan Police')
        LEFT JOIN dbo.DIM_VEHICULE veh 
            ON veh.vehicle_type_key = 1
        LEFT JOIN dbo.DIM_CONDUCTEUR drv 
            ON drv.driver_key = 1
        LEFT JOIN dbo.DIM_MANOEUVRE man 
            ON man.manoeuvre_key = 1
        LEFT JOIN dbo.DIM_VICTIME vic 
            ON vic.casualty_key = 1;

        SET @RowsAffected = @@ROWCOUNT;

        IF @MasterLogID IS NOT NULL AND OBJECT_ID('dbo.sp_ETL_Log_End', 'P') IS NOT NULL
        BEGIN
            EXEC dbo.sp_ETL_Log_End 
                @LogID = @MasterLogID,
                @Status = 'SUCCESS',
                @RowsRead = @MaxFactRows,
                @RowsInserted = @RowsAffected;
        END

        PRINT '=============================================================================';
        PRINT '  PIPELINE TERMINE AVEC SUCCES : ' + CAST(@RowsAffected AS VARCHAR(10)) + ' LIGNES DANS FACT_COLLISION.';
        PRINT '=============================================================================';
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrLine INT = ERROR_LINE();

        IF @MasterLogID IS NOT NULL AND OBJECT_ID('dbo.sp_ETL_Log_End', 'P') IS NOT NULL
        BEGIN
            EXEC dbo.sp_ETL_Log_End 
                @LogID = @MasterLogID,
                @Status = 'FAILED',
                @ErrorMessage = @ErrMsg,
                @ErrorLine = @ErrLine;
        END

        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END;
GO

PRINT 'Procédure dbo.sp_Run_Full_ETL_DW déployée avec succès.';
GO

-- Exécution immédiate pour alimenter les tables
EXEC dbo.sp_Run_Full_ETL_DW;
GO

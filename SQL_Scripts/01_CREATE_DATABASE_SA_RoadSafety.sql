-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script 01 : Création de la Base de Données Staging Area (SA_RoadSafety)
-- Zone de transit (Staging Area) avec types permissifs pour ingestion robuste
-- =================================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'SA_RoadSafety')
BEGIN
    CREATE DATABASE SA_RoadSafety;
    PRINT 'Base de données SA_RoadSafety créée avec succès.';
END
ELSE
BEGIN
    PRINT 'La base de données SA_RoadSafety existe déjà.';
END
GO

USE SA_RoadSafety;
GO

-- 1. Table Staging pour les Collisions
IF OBJECT_ID('dbo.SA_Collision', 'U') IS NOT NULL
    DROP TABLE dbo.SA_Collision;
GO

CREATE TABLE dbo.SA_Collision (
    collision_index VARCHAR(50) NOT NULL,
    collision_year VARCHAR(50) NULL,
    collision_ref_no VARCHAR(50) NULL,
    location_easting_osgr VARCHAR(50) NULL,
    location_northing_osgr VARCHAR(50) NULL,
    longitude VARCHAR(50) NULL,
    latitude VARCHAR(50) NULL,
    police_force VARCHAR(50) NULL,
    collision_severity VARCHAR(50) NULL,
    number_of_vehicles VARCHAR(50) NULL,
    number_of_casualties VARCHAR(50) NULL,
    date VARCHAR(50) NULL,
    day_of_week VARCHAR(50) NULL,
    time VARCHAR(50) NULL,
    local_authority_district VARCHAR(50) NULL,
    local_authority_ons_district VARCHAR(50) NULL,
    local_authority_highway VARCHAR(50) NULL,
    local_authority_highway_current VARCHAR(50) NULL,
    first_road_class VARCHAR(50) NULL,
    first_road_number VARCHAR(50) NULL,
    road_type VARCHAR(50) NULL,
    speed_limit VARCHAR(50) NULL,
    junction_detail_historic VARCHAR(50) NULL,
    junction_detail VARCHAR(50) NULL,
    junction_control VARCHAR(50) NULL,
    second_road_class VARCHAR(50) NULL,
    second_road_number VARCHAR(50) NULL,
    pedestrian_crossing_human_control_historic VARCHAR(50) NULL,
    pedestrian_crossing_physical_facilities_historic VARCHAR(50) NULL,
    pedestrian_crossing VARCHAR(50) NULL,
    light_conditions VARCHAR(50) NULL,
    weather_conditions VARCHAR(50) NULL,
    road_surface_conditions VARCHAR(50) NULL,
    special_conditions_at_site VARCHAR(50) NULL,
    carriageway_hazards_historic VARCHAR(50) NULL,
    carriageway_hazards VARCHAR(50) NULL,
    urban_or_rural_area VARCHAR(50) NULL,
    did_police_officer_attend_scene_of_accident VARCHAR(50) NULL,
    trunk_road_flag VARCHAR(50) NULL,
    lsoa_of_accident_location VARCHAR(50) NULL,
    enhanced_severity_collision VARCHAR(50) NULL,
    collision_injury_based VARCHAR(50) NULL,
    collision_adjusted_severity_serious VARCHAR(50) NULL,
    collision_adjusted_severity_slight VARCHAR(50) NULL,
    date_chargement_sa DATETIME DEFAULT GETDATE()
);
GO

CREATE CLUSTERED INDEX CIX_SA_Collision ON dbo.SA_Collision(collision_index);
GO

-- 2. Table Staging pour les Véhicules
IF OBJECT_ID('dbo.SA_Vehicle', 'U') IS NOT NULL
    DROP TABLE dbo.SA_Vehicle;
GO

CREATE TABLE dbo.SA_Vehicle (
    collision_index VARCHAR(50) NOT NULL,
    collision_year VARCHAR(50) NULL,
    collision_ref_no VARCHAR(50) NULL,
    vehicle_reference VARCHAR(50) NULL,
    vehicle_type VARCHAR(50) NULL,
    towing_and_articulation VARCHAR(50) NULL,
    vehicle_manoeuvre_historic VARCHAR(50) NULL,
    vehicle_manoeuvre VARCHAR(50) NULL,
    vehicle_direction_from VARCHAR(50) NULL,
    vehicle_direction_to VARCHAR(50) NULL,
    vehicle_location_restricted_lane_historic VARCHAR(50) NULL,
    vehicle_location_restricted_lane VARCHAR(50) NULL,
    junction_location VARCHAR(50) NULL,
    skidding_and_overturning VARCHAR(50) NULL,
    hit_object_in_carriageway VARCHAR(50) NULL,
    vehicle_leaving_carriageway VARCHAR(50) NULL,
    hit_object_off_carriageway VARCHAR(50) NULL,
    first_point_of_impact VARCHAR(50) NULL,
    vehicle_left_hand_drive VARCHAR(50) NULL,
    journey_purpose_of_driver_historic VARCHAR(50) NULL,
    journey_purpose_of_driver VARCHAR(50) NULL,
    sex_of_driver VARCHAR(50) NULL,
    age_of_driver VARCHAR(50) NULL,
    age_band_of_driver VARCHAR(50) NULL,
    engine_capacity_cc VARCHAR(50) NULL,
    propulsion_code VARCHAR(50) NULL,
    age_of_vehicle VARCHAR(50) NULL,
    generic_make_model VARCHAR(100) NULL,
    driver_imd_decile VARCHAR(50) NULL,
    lsoa_of_driver VARCHAR(50) NULL,
    escooter_flag VARCHAR(50) NULL,
    driver_distance_banding VARCHAR(50) NULL,
    date_chargement_sa DATETIME DEFAULT GETDATE()
);
GO

CREATE CLUSTERED INDEX CIX_SA_Vehicle ON dbo.SA_Vehicle(collision_index, vehicle_reference);
GO

-- 3. Table Staging pour les Victimes
IF OBJECT_ID('dbo.SA_Casualty', 'U') IS NOT NULL
    DROP TABLE dbo.SA_Casualty;
GO

CREATE TABLE dbo.SA_Casualty (
    collision_index VARCHAR(50) NOT NULL,
    collision_year VARCHAR(50) NULL,
    collision_ref_no VARCHAR(50) NULL,
    vehicle_reference VARCHAR(50) NULL,
    casualty_reference VARCHAR(50) NULL,
    casualty_class VARCHAR(50) NULL,
    sex_of_casualty VARCHAR(50) NULL,
    age_of_casualty VARCHAR(50) NULL,
    age_band_of_casualty VARCHAR(50) NULL,
    casualty_severity VARCHAR(50) NULL,
    pedestrian_location VARCHAR(50) NULL,
    pedestrian_movement VARCHAR(50) NULL,
    car_passenger VARCHAR(50) NULL,
    bus_or_coach_passenger VARCHAR(50) NULL,
    pedestrian_road_maintenance_worker VARCHAR(50) NULL,
    casualty_type VARCHAR(50) NULL,
    casualty_imd_decile VARCHAR(50) NULL,
    lsoa_of_casualty VARCHAR(50) NULL,
    enhanced_casualty_severity VARCHAR(50) NULL,
    casualty_injury_based VARCHAR(50) NULL,
    casualty_adjusted_severity_serious VARCHAR(50) NULL,
    casualty_adjusted_severity_slight VARCHAR(50) NULL,
    casualty_distance_banding VARCHAR(50) NULL,
    escooter_flag VARCHAR(50) NULL,
    date_chargement_sa DATETIME DEFAULT GETDATE()
);
GO

CREATE CLUSTERED INDEX CIX_SA_Casualty ON dbo.SA_Casualty(collision_index, vehicle_reference, casualty_reference);
GO

-- 4. Procédure Stockée de Vidage
IF OBJECT_ID('dbo.sp_Truncate_SA', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Truncate_SA;
GO

CREATE PROCEDURE dbo.sp_Truncate_SA
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dbo.SA_Casualty;
    TRUNCATE TABLE dbo.SA_Vehicle;
    TRUNCATE TABLE dbo.SA_Collision;
    PRINT 'Tables de la Staging Area vidées avec succès.';
END;
GO

-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script 02 : Création de la Base de Données Data Warehouse (DW_RoadSafety)
-- Modélisation Dimensionnelle EXACTE : 10 Dimensions + 1 Table de Faits (FACT_COLLISION)
-- =================================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'DW_RoadSafety')
BEGIN
    CREATE DATABASE DW_RoadSafety;
    PRINT 'Base de données DW_RoadSafety créée avec succès.';
END
ELSE
BEGIN
    PRINT 'La base de données DW_RoadSafety existe déjà.';
END
GO

USE DW_RoadSafety;
GO

-- -----------------------------------------------------------------------------
-- Nettoyage des anciennes tables pour reconstruction propre
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.FACT_COLLISION', 'U') IS NOT NULL DROP TABLE dbo.FACT_COLLISION;
IF OBJECT_ID('dbo.FaitVictime', 'U') IS NOT NULL DROP TABLE dbo.FaitVictime;
IF OBJECT_ID('dbo.FaitCollision', 'U') IS NOT NULL DROP TABLE dbo.FaitCollision;

IF OBJECT_ID('dbo.DIM_TEMPS', 'U') IS NOT NULL DROP TABLE dbo.DIM_TEMPS;
IF OBJECT_ID('dbo.DIM_LIEU', 'U') IS NOT NULL DROP TABLE dbo.DIM_LIEU;
IF OBJECT_ID('dbo.DIM_JONCTION', 'U') IS NOT NULL DROP TABLE dbo.DIM_JONCTION;
IF OBJECT_ID('dbo.DIM_CONDITIONS', 'U') IS NOT NULL DROP TABLE dbo.DIM_CONDITIONS;
IF OBJECT_ID('dbo.DIM_POLICE', 'U') IS NOT NULL DROP TABLE dbo.DIM_POLICE;
IF OBJECT_ID('dbo.DIM_ROAD', 'U') IS NOT NULL DROP TABLE dbo.DIM_ROAD;
IF OBJECT_ID('dbo.DIM_VEHICULE', 'U') IS NOT NULL DROP TABLE dbo.DIM_VEHICULE;
IF OBJECT_ID('dbo.DIM_CONDUCTEUR', 'U') IS NOT NULL DROP TABLE dbo.DIM_CONDUCTEUR;
IF OBJECT_ID('dbo.DIM_MANOEUVRE', 'U') IS NOT NULL DROP TABLE dbo.DIM_MANOEUVRE;
IF OBJECT_ID('dbo.DIM_VICTIME', 'U') IS NOT NULL DROP TABLE dbo.DIM_VICTIME;

-- Nettoyage anciens schémas éventuels
IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL DROP TABLE dbo.DimDate;
IF OBJECT_ID('dbo.DimLocalisation', 'U') IS NOT NULL DROP TABLE dbo.DimLocalisation;
IF OBJECT_ID('dbo.DimConditions', 'U') IS NOT NULL DROP TABLE dbo.DimConditions;
IF OBJECT_ID('dbo.DimCarrefour', 'U') IS NOT NULL DROP TABLE dbo.DimCarrefour;
IF OBJECT_ID('dbo.DimVehicule', 'U') IS NOT NULL DROP TABLE dbo.DimVehicule;
IF OBJECT_ID('dbo.DimUsager', 'U') IS NOT NULL DROP TABLE dbo.DimUsager;
GO

-- =============================================================================
-- 1. LES 10 DIMENSIONS DU DATA WAREHOUSE
-- =============================================================================

-- 1.1 DIM_TEMPS (Dimension Temporelle)
CREATE TABLE dbo.DIM_TEMPS (
    temps_key INT PRIMARY KEY,                       -- Format YYYYMMDD (ex: 20210101)
    date DATE NOT NULL,
    day_of_week TINYINT NOT NULL,                    -- 1 à 7
    day_name VARCHAR(10) NOT NULL,                   -- 'Lundi', 'Mardi'...
    month TINYINT NOT NULL,                          -- 1 à 12
    month_name VARCHAR(10) NOT NULL,                 -- 'Janvier', 'Février'...
    quarter TINYINT NOT NULL,                        -- 1 à 4
    year SMALLINT NOT NULL,                          -- 2018 à 2030
    hour TINYINT NULL,                               -- 0 à 23
    minute TINYINT NULL,                             -- 0 à 59
    time_band VARCHAR(20) NULL,                      -- 'Journée', 'Nuit', 'Pointe Matin'...
    is_weekend BIT NOT NULL DEFAULT 0,
    is_school_holiday BIT NOT NULL DEFAULT 0,
    is_rush_hour BIT NOT NULL DEFAULT 0,
    is_night BIT NOT NULL DEFAULT 0
);
GO

-- 1.2 DIM_LIEU (Dimension Géographique)
CREATE TABLE dbo.DIM_LIEU (
    location_key INT IDENTITY(1,1) PRIMARY KEY,
    longitude DECIMAL(9,6) NULL,
    latitude DECIMAL(9,6) NULL,
    lsoa_code VARCHAR(20) NULL,
    lsoa_name VARCHAR(100) NULL,
    local_authority_district VARCHAR(100) NULL,
    local_authority_name VARCHAR(100) NULL,
    police_force VARCHAR(50) NULL,
    rural_urban_area VARCHAR(10) NULL,
    region VARCHAR(50) NULL,
    country VARCHAR(50) NULL
);
GO

-- 1.3 DIM_JONCTION (Dimension Infrastructure & Carrefour)
CREATE TABLE dbo.DIM_JONCTION (
    junction_key INT IDENTITY(1,1) PRIMARY KEY,
    junction_detail VARCHAR(50) NULL,
    junction_control VARCHAR(50) NULL,
    junction_type VARCHAR(50) NULL,
    pedestrian_crossing VARCHAR(10) NULL,
    second_road_class VARCHAR(10) NULL
);
GO

-- 1.4 DIM_CONDITIONS (Dimension Environnementale & Météorologique)
CREATE TABLE dbo.DIM_CONDITIONS (
    condition_key INT IDENTITY(1,1) PRIMARY KEY,
    light_conditions VARCHAR(50) NULL,
    weather_conditions VARCHAR(50) NULL,
    road_surface_conditions VARCHAR(50) NULL,
    carriageway_hazards VARCHAR(50) NULL,
    special_conditions_at_site VARCHAR(50) NULL
);
GO

-- 1.5 DIM_POLICE (Dimension Administrative & Intervention)
CREATE TABLE dbo.DIM_POLICE (
    police_key INT IDENTITY(1,1) PRIMARY KEY,
    police_force VARCHAR(50) NULL,
    did_police_attend BIT NOT NULL DEFAULT 0,
    scene_of_accident BIT NOT NULL DEFAULT 0,
    injury_based BIT NOT NULL DEFAULT 0,
    report_type VARCHAR(50) NULL
);
GO

-- 1.6 DIM_ROAD (Dimension Réseau Routier)
CREATE TABLE dbo.DIM_ROAD (
    road_key INT IDENTITY(1,1) PRIMARY KEY,
    road_type VARCHAR(50) NULL,
    first_road_class VARCHAR(10) NULL,
    second_road_class VARCHAR(10) NULL,
    road_number VARCHAR(20) NULL,
    speed_limit SMALLINT NULL,
    carriageway_hazards VARCHAR(50) NULL,
    urban_or_rural_area VARCHAR(10) NULL,
    is_itineraire BIT NOT NULL DEFAULT 0
);
GO

-- 1.7 DIM_VEHICULE (Dimension Véhicules Impliqués)
CREATE TABLE dbo.DIM_VEHICULE (
    vehicle_type_key INT IDENTITY(1,1) PRIMARY KEY,
    vehicle_type VARCHAR(50) NULL,
    towing_and_articulation VARCHAR(20) NULL,
    propulsion_code VARCHAR(20) NULL,
    fuel_type VARCHAR(20) NULL,
    engine_capacity_cc INT NULL,
    euro_status VARCHAR(20) NULL,
    vehicle_age SMALLINT NULL,
    vehicle_make VARCHAR(50) NULL,
    vehicle_model VARCHAR(50) NULL,
    vehicle_colour VARCHAR(30) NULL,
    vehicle_category VARCHAR(30) NULL
);
GO

-- 1.8 DIM_CONDUCTEUR (Dimension Profil Conducteur)
CREATE TABLE dbo.DIM_CONDUCTEUR (
    driver_key INT IDENTITY(1,1) PRIMARY KEY,
    age_of_driver SMALLINT NULL,
    age_band_driver VARCHAR(20) NULL,
    sex_of_driver VARCHAR(10) NULL,
    driver_imd_decile TINYINT NULL,
    driving_experience_years SMALLINT NULL,
    driver_home_area_type VARCHAR(20) NULL
);
GO

-- 1.9 DIM_MANOEUVRE (Dimension Dynamique & Manœuvre de l'Accident)
CREATE TABLE dbo.DIM_MANOEUVRE (
    manoeuvre_key INT IDENTITY(1,1) PRIMARY KEY,
    vehicle_manoeuvre VARCHAR(50) NULL,
    first_point_of_impact VARCHAR(50) NULL,
    vehicle_leaving_carriageway BIT NOT NULL DEFAULT 0,
    skidding_and_overturning BIT NOT NULL DEFAULT 0,
    hit_object_in_carriageway BIT NOT NULL DEFAULT 0,
    vehicle_movement VARCHAR(50) NULL
);
GO

-- 1.10 DIM_VICTIME (Dimension Gravité & Usagers Corporels)
CREATE TABLE dbo.DIM_VICTIME (
    casualty_key INT IDENTITY(1,1) PRIMARY KEY,
    casualty_class VARCHAR(50) NULL,
    casualty_type VARCHAR(50) NULL,
    age_of_casualty SMALLINT NULL,
    age_band_casualty VARCHAR(20) NULL,
    sex_of_casualty VARCHAR(10) NULL,
    pedestrian_location VARCHAR(50) NULL,
    pedestrian_movement VARCHAR(50) NULL,
    car_passenger_seat VARCHAR(50) NULL,
    bus_or_coach_passenger BIT NOT NULL DEFAULT 0,
    usager_vulnerable BIT NOT NULL DEFAULT 0,
    casualty_home_area_type VARCHAR(20) NULL
);
GO

-- =============================================================================
-- 2. TABLE DE FAITS : FACT_COLLISION
-- =============================================================================
CREATE TABLE dbo.FACT_COLLISION (
    collision_id INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Clés Étrangères vers les 10 Dimensions
    temps_key INT NOT NULL REFERENCES dbo.DIM_TEMPS(temps_key),
    location_key INT NOT NULL REFERENCES dbo.DIM_LIEU(location_key),
    road_key INT NOT NULL REFERENCES dbo.DIM_ROAD(road_key),
    junction_key INT NOT NULL REFERENCES dbo.DIM_JONCTION(junction_key),
    condition_key INT NOT NULL REFERENCES dbo.DIM_CONDITIONS(condition_key),
    police_key INT NOT NULL REFERENCES dbo.DIM_POLICE(police_key),
    vehicle_type_key INT NOT NULL REFERENCES dbo.DIM_VEHICULE(vehicle_type_key),
    driver_key INT NOT NULL REFERENCES dbo.DIM_CONDUCTEUR(driver_key),
    manoeuvre_key INT NOT NULL REFERENCES dbo.DIM_MANOEUVRE(manoeuvre_key),
    casualty_key INT NOT NULL REFERENCES dbo.DIM_VICTIME(casualty_key),
    
    -- Mesures & Indicateurs Métier
    number_of_vehicles TINYINT NOT NULL DEFAULT 1,
    number_of_casualties TINYINT NOT NULL DEFAULT 1,
    collision_severity TINYINT NOT NULL DEFAULT 3,
    gravity_adjusted_crash SMALLINT NOT NULL DEFAULT 1,
    score_point_noir DECIMAL(6,3) NOT NULL DEFAULT 0.000,
    cost_societal_gbp DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    est_ksi BIT NOT NULL DEFAULT 0
);
GO

-- Index sur les Clés Étrangères pour optimiser les requêtes analytiques (BI)
CREATE INDEX IX_FACT_Temps ON dbo.FACT_COLLISION(temps_key);
CREATE INDEX IX_FACT_Location ON dbo.FACT_COLLISION(location_key);
CREATE INDEX IX_FACT_Road ON dbo.FACT_COLLISION(road_key);
CREATE INDEX IX_FACT_Junction ON dbo.FACT_COLLISION(junction_key);
CREATE INDEX IX_FACT_Condition ON dbo.FACT_COLLISION(condition_key);
CREATE INDEX IX_FACT_Police ON dbo.FACT_COLLISION(police_key);
CREATE INDEX IX_FACT_Vehicule ON dbo.FACT_COLLISION(vehicle_type_key);
CREATE INDEX IX_FACT_Driver ON dbo.FACT_COLLISION(driver_key);
CREATE INDEX IX_FACT_Manoeuvre ON dbo.FACT_COLLISION(manoeuvre_key);
CREATE INDEX IX_FACT_Victime ON dbo.FACT_COLLISION(casualty_key);
GO

PRINT 'Schéma dimensionnel DW_RoadSafety (FACT_COLLISION + 10 Dimensions) déployé avec succès.';

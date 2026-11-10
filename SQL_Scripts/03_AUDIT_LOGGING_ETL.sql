-- =================================================================================
-- PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
-- Système Décisionnel pour la Sécurité Routière (UK STATS19)
-- Script 03 : Cadre d'Audit, Logging Automatique & Dashboard
-- Modélisation Ralph Kimball & Bonnes Pratiques Microsoft BI (SSIS / SSMS)
-- =================================================================================

USE DW_RoadSafety;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 1. Table d'Audit et Journalisation des Exécutions ETL (ETL_Execution_Log)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.ETL_Execution_Log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_Execution_Log (
        LogID BIGINT IDENTITY(1,1) PRIMARY KEY,
        BatchID UNIQUEIDENTIFIER NOT NULL,
        PackageName VARCHAR(100) NOT NULL,
        StepName VARCHAR(100) NOT NULL,
        StepType VARCHAR(50) NOT NULL,            -- 'STAGING_TRUNCATE', 'STAGING_EXTRACT', 'DIMENSION_LOAD', 'FACT_LOAD'
        SourceTable VARCHAR(100) NULL,
        TargetTable VARCHAR(100) NULL,
        RowsRead INT DEFAULT 0,
        RowsInserted INT DEFAULT 0,
        RowsUpdated INT DEFAULT 0,
        RowsRejected INT DEFAULT 0,
        StartTime DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EndTime DATETIME2 NULL,
        DurationSeconds AS DATEDIFF(SECOND, StartTime, EndTime),
        Status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',  -- 'RUNNING', 'SUCCESS', 'FAILED'
        ErrorMessage NVARCHAR(MAX) NULL,
        ErrorLine INT NULL,
        HostMachine VARCHAR(100) DEFAULT HOST_NAME(),
        ExecutedBy VARCHAR(100) DEFAULT SUSER_SNAME()
    );

    CREATE INDEX IX_ETL_Log_BatchID ON dbo.ETL_Execution_Log(BatchID);
    CREATE INDEX IX_ETL_Log_Status ON dbo.ETL_Execution_Log(Status);
    PRINT 'Table dbo.ETL_Execution_Log créée avec succès.';
END
ELSE
BEGIN
    PRINT 'Table dbo.ETL_Execution_Log existe déjà.';
END
GO

-- -----------------------------------------------------------------------------
-- 2. Procédures de Gestion du Logging ETL (Start & End)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.sp_ETL_Log_Start', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ETL_Log_Start;
GO

CREATE PROCEDURE dbo.sp_ETL_Log_Start
    @BatchID UNIQUEIDENTIFIER,
    @PackageName VARCHAR(100),
    @StepName VARCHAR(100),
    @StepType VARCHAR(50),
    @SourceTable VARCHAR(100) = NULL,
    @TargetTable VARCHAR(100) = NULL,
    @LogID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ETL_Execution_Log (
        BatchID, PackageName, StepName, StepType, SourceTable, TargetTable,
        StartTime, Status
    )
    VALUES (
        @BatchID, @PackageName, @StepName, @StepType, @SourceTable, @TargetTable,
        SYSDATETIME(), 'RUNNING'
    );
    SET @LogID = SCOPE_IDENTITY();
END;
GO

IF OBJECT_ID('dbo.sp_ETL_Log_End', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_ETL_Log_End;
GO

CREATE PROCEDURE dbo.sp_ETL_Log_End
    @LogID BIGINT,
    @Status VARCHAR(20),
    @RowsRead INT = 0,
    @RowsInserted INT = 0,
    @RowsUpdated INT = 0,
    @RowsRejected INT = 0,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @ErrorLine INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ETL_Execution_Log
    SET EndTime = SYSDATETIME(),
        Status = @Status,
        RowsRead = @RowsRead,
        RowsInserted = @RowsInserted,
        RowsUpdated = @RowsUpdated,
        RowsRejected = @RowsRejected,
        ErrorMessage = @ErrorMessage,
        ErrorLine = @ErrorLine
    WHERE LogID = @LogID;
END;
GO

-- -----------------------------------------------------------------------------
-- 3. Vue d'Audit et Tableau de Bord Décisionnel (vw_ETL_Audit_Dashboard)
-- -----------------------------------------------------------------------------
IF OBJECT_ID('dbo.vw_ETL_Audit_Dashboard', 'V') IS NOT NULL DROP VIEW dbo.vw_ETL_Audit_Dashboard;
GO

CREATE VIEW dbo.vw_ETL_Audit_Dashboard AS
SELECT 
    LogID,
    BatchID,
    PackageName,
    StepName,
    StepType,
    SourceTable,
    TargetTable,
    RowsRead,
    RowsInserted,
    RowsUpdated,
    RowsRejected,
    StartTime,
    EndTime,
    DurationSeconds,
    Status,
    ErrorMessage,
    ExecutedBy,
    HostMachine
FROM dbo.ETL_Execution_Log;
GO

PRINT 'Cadre d''audit et de journalisation déployé avec succès.';

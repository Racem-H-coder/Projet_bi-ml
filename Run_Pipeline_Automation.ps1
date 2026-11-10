# =================================================================================
# PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
# Système Décisionnel pour la Sécurité Routière (UK STATS19)
# Script Master : Orchestration, Exécution Automatisée & Audit End-to-End
# =================================================================================

param (
    [string]$ServerInstance = ".",
    [string]$StagingDB = "SA_RoadSafety",
    [string]$WarehouseDB = "DW_RoadSafety",
    [int]$MaxRows = 50000,
    [ValidateSet("Full", "StagingOnly", "WarehouseOnly", "VerifyOnly")]
    [string]$ExecutionMode = "Full",
    [switch]$UseSSIS = $true,
    [ValidateSet("ETL_SA_DW.dtsx", "ETL_SA_DW_Distrisys.dtsx")]
    [string]$ETLPackage = "ETL_SA_DW.dtsx"
)

$ErrorActionPreference = "Stop"

$workspaceDir = "c:\Users\medra\Documents\ESPRIT\Projet Data werehouse- DW"
$ssisDir = Join-Path $workspaceDir "SSIS_RoadSafety"
$sqlDir = Join-Path $workspaceDir "SQL_Scripts"
$dtexecPath = "C:\Program Files\Microsoft SQL Server\160\DTS\Binn\DTExec.exe"

$batchId = [guid]::NewGuid().ToString()
$startTime = Get-Date

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "       ORCHESTRATION PIPELINE DECISIONNEL SSIS / SQL SERVER (STATS19)           " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Date / Heure       : $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "  Instance SQL       : $ServerInstance" -ForegroundColor Yellow
Write-Host "  Base Staging       : $StagingDB" -ForegroundColor Yellow
Write-Host "  Base Warehouse     : $WarehouseDB" -ForegroundColor Yellow
Write-Host "  Mode d'Exécution   : $ExecutionMode" -ForegroundColor Yellow
Write-Host "  Moteur SSIS        : $(if ($UseSSIS) { 'DTExec.exe (SSIS Engine)' } else { 'Direct T-SQL Stored Procs' })" -ForegroundColor Yellow
Write-Host "  Batch ID Unique    : $batchId" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Vérifications Préalables
# -----------------------------------------------------------------------------
Write-Host "`n[1/5] Vérification des prérequis et connectivité..." -ForegroundColor Green

if ($UseSSIS -and (-not (Test-Path $dtexecPath))) {
    Write-Host "AVERTISSEMENT: DTExec.exe introuvable à l'emplacement standard ($dtexecPath). Bascule automatique en mode T-SQL." -ForegroundColor Yellow
    $UseSSIS = $false
}

$connStr = "Server=$ServerInstance;Database=$WarehouseDB;Integrated Security=True;TrustServerCertificate=True;"

# -----------------------------------------------------------------------------
# Étape 1 : Ingestion Staging Area (CSV -> SA)
# -----------------------------------------------------------------------------
if ($ExecutionMode -in @("Full", "StagingOnly")) {
    Write-Host "`n[2/5] Exécution Phase 1 : Ingestion CSV vers Staging Area ($StagingDB)..." -ForegroundColor Green
    
    $ispacLocal = Join-Path $ssisDir "bin\Development\RoadSafety_SSIS.ispac"
    $ispacRepos = "C:\Users\medra\source\repos\RoadSafety_SSIS\bin\Development\RoadSafety_SSIS.ispac"
    $ispacPath = if (Test-Path $ispacLocal) { $ispacLocal } elseif (Test-Path $ispacRepos) { $ispacRepos } else { $null }
    if ($UseSSIS -and $ispacPath) {
        Write-Host "-> Lancement du package SSIS via DTExec: EL_CSV_SA.dtsx" -ForegroundColor Cyan
        $p = Start-Process -FilePath $dtexecPath -ArgumentList "/Project `"$ispacPath`" /Package `"EL_CSV_SA.dtsx`"" -NoNewWindow -PassThru -Wait
        if ($p.ExitCode -ne 0) {
            Write-Error "Échec de l'ingestion Staging Area via EL_CSV_SA.dtsx (Code: $($p.ExitCode))."
        }
        Write-Host "-> Package SSIS EL_CSV_SA.dtsx terminé avec succès." -ForegroundColor Green
    } else {
        $ingestScript = Join-Path $sqlDir "00_INGEST_CSV_TO_SA.ps1"
        & powershell.exe -ExecutionPolicy Bypass -File $ingestScript -ServerInstance $ServerInstance -StagingDB $StagingDB -WarehouseDB $WarehouseDB -MaxRows $MaxRows -BatchID $batchId
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Échec de l'ingestion Staging Area."
        }
    }
} else {
    Write-Host "`n[2/5] Phase 1 sautée (Mode: $ExecutionMode)." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# Étape 2 : Chargement Data Warehouse (SA -> DW)
# -----------------------------------------------------------------------------
if ($ExecutionMode -in @("Full", "WarehouseOnly")) {
    Write-Host "`n[3/5] Exécution Phase 2 : Alimentation Data Warehouse ($WarehouseDB)..." -ForegroundColor Green
    
    if ($UseSSIS -and $ispacPath) {
        Write-Host "-> Lancement du package SSIS via DTExec (Mode Projet .ispac): $ETLPackage" -ForegroundColor Cyan
        $p = Start-Process -FilePath $dtexecPath -ArgumentList "/Project `"$ispacPath`" /Package `"$ETLPackage`"" -NoNewWindow -PassThru -Wait
        if ($p.ExitCode -ne 0) {
            Write-Error "Échec de l'exécution du package SSIS $ETLPackage (Code: $($p.ExitCode))."
        }
        Write-Host "-> Package SSIS $ETLPackage terminé avec succès." -ForegroundColor Green
    } else {
        Write-Host "-> Exécution directe de la procédure maître sp_Run_Full_ETL_DW..." -ForegroundColor Cyan
        sqlcmd -S $ServerInstance -E -d $WarehouseDB -Q "EXEC dbo.sp_Run_Full_ETL_DW @BatchID = '$batchId';"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Échec de l'exécution de la procédure sp_Run_Full_ETL_DW."
        }
    }
} else {
    Write-Host "`n[3/5] Phase 2 sautée (Mode: $ExecutionMode)." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# Étape 3 : Consultation du Journal d'Audit ETL
# -----------------------------------------------------------------------------
Write-Host "`n[4/5] Tableau de Bord d'Audit ETL (Dernières Opérations)..." -ForegroundColor Green

$auditQuery = @"
SET NOCOUNT ON;
SELECT TOP 12 
    CAST(LogID AS VARCHAR(5)) AS [ID],
    CAST(StepName AS VARCHAR(40)) AS [Etape],
    CAST(StepType AS VARCHAR(18)) AS [Type],
    CAST(RowsInserted AS VARCHAR(8)) AS [Insérés],
    CAST(RowsUpdated AS VARCHAR(8)) AS [Expirés],
    CAST(DurationSeconds AS VARCHAR(6)) + 's' AS [Durée],
    CAST(Status AS VARCHAR(10)) AS [Statut]
FROM dbo.ETL_Execution_Log
ORDER BY LogID DESC;
"@

sqlcmd -S $ServerInstance -E -d $WarehouseDB -Q $auditQuery -W

# -----------------------------------------------------------------------------
# Étape 4 : Restitution des KPIs Clés Décisionnels
# -----------------------------------------------------------------------------
Write-Host "`n[5/5] Indicateurs & KPIs Métier du Data Warehouse..." -ForegroundColor Green

$kpiSummaryQuery = @"
SET NOCOUNT ON;
PRINT '--- A. Volume Global des 10 Dimensions & Table de Faits ---';
SELECT 'DIM_TEMPS' AS Table_Name, COUNT(*) AS Total_Rows FROM dbo.DIM_TEMPS
UNION ALL SELECT 'DIM_LIEU', COUNT(*) FROM dbo.DIM_LIEU
UNION ALL SELECT 'DIM_CONDITIONS', COUNT(*) FROM dbo.DIM_CONDITIONS
UNION ALL SELECT 'DIM_JONCTION', COUNT(*) FROM dbo.DIM_JONCTION
UNION ALL SELECT 'DIM_POLICE', COUNT(*) FROM dbo.DIM_POLICE
UNION ALL SELECT 'DIM_ROAD', COUNT(*) FROM dbo.DIM_ROAD
UNION ALL SELECT 'DIM_VEHICULE', COUNT(*) FROM dbo.DIM_VEHICULE
UNION ALL SELECT 'DIM_CONDUCTEUR', COUNT(*) FROM dbo.DIM_CONDUCTEUR
UNION ALL SELECT 'DIM_MANOEUVRE', COUNT(*) FROM dbo.DIM_MANOEUVRE
UNION ALL SELECT 'DIM_VICTIME', COUNT(*) FROM dbo.DIM_VICTIME
UNION ALL SELECT 'FACT_COLLISION', COUNT(*) FROM dbo.FACT_COLLISION;

PRINT '--- B. Synthese Analytique & Indicateurs Cles (FACT_COLLISION) ---';
SELECT 
    COUNT(*) AS Total_Collisions,
    SUM(CAST(number_of_casualties AS INT)) AS Total_Victimes,
    SUM(CAST(est_ksi AS INT)) AS Total_Accidents_Graves_Mortels_KSI,
    ROUND(AVG(score_point_noir), 3) AS Score_Moyen_Point_Noir,
    FORMAT(SUM(cost_societal_gbp), 'N0') + ' GBP' AS Cout_Societal_Total_GBP
FROM dbo.FACT_COLLISION;

PRINT '--- C. Top 5 Zones par Cout Societal et Gravite ---';
SELECT TOP 5
    p.police_force AS Police,
    l.urban_or_rural_area AS Milieu,
    COUNT(f.collision_id) AS TotalAccidents,
    SUM(CAST(f.est_ksi AS INT)) AS Accidents_Graves_KSI,
    FORMAT(SUM(f.cost_societal_gbp), 'N0') + ' GBP' AS Cout_Societal_GBP
FROM dbo.FACT_COLLISION f
INNER JOIN dbo.DIM_LIEU l ON f.location_key = l.location_key
INNER JOIN dbo.DIM_POLICE p ON f.police_key = p.police_key
GROUP BY p.police_force, l.urban_or_rural_area
ORDER BY SUM(f.cost_societal_gbp) DESC;
"@

sqlcmd -S $ServerInstance -E -d $WarehouseDB -Q $kpiSummaryQuery -W

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  PIPELINE DECISIONNEL EXECUTE AVEC SUCCES EN $([math]::Round($duration, 2)) SECONDES !  " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

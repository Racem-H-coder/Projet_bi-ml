# =================================================================================
# PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
# Script : Ingestion Optimisée des Fichiers CSV vers SA_RoadSafety
# Utilise ADO.NET SqlBulkCopy avec Truncate et Journalisation dans ETL_Execution_Log
# =================================================================================

param (
    [string]$ServerInstance = ".",
    [string]$StagingDB = "SA_RoadSafety",
    [string]$WarehouseDB = "DW_RoadSafety",
    [string]$DataDir = "c:\Users\medra\Documents\ESPRIT\Projet Data werehouse- DW\Data 5years",
    [int]$MaxRows = 50000,
    [string]$BatchID = $([guid]::NewGuid().ToString())
)

Add-Type -AssemblyName System.Data

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  INGESTION CSV -> STAGING AREA ($StagingDB) - BATCH: $BatchID" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

$saConnStr = "Server=$ServerInstance;Database=$StagingDB;Integrated Security=True;TrustServerCertificate=True;"
$dwConnStr = "Server=$ServerInstance;Database=$WarehouseDB;Integrated Security=True;TrustServerCertificate=True;"

$saConn = New-Object System.Data.SqlClient.SqlConnection($saConnStr)
$dwConn = New-Object System.Data.SqlClient.SqlConnection($dwConnStr)

$saConn.Open()
$dwConn.Open()

function Log-ETLStart($stepName, $srcTable, $tgtTable) {
    $cmd = $dwConn.CreateCommand()
    $cmd.CommandText = "dbo.sp_ETL_Log_Start"
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.Parameters.AddWithValue("@BatchID", [guid]$BatchID) | Out-Null
    $cmd.Parameters.AddWithValue("@PackageName", "EL_CSV_SA.dtsx") | Out-Null
    $cmd.Parameters.AddWithValue("@StepName", $stepName) | Out-Null
    $cmd.Parameters.AddWithValue("@StepType", "STAGING_EXTRACT") | Out-Null
    $cmd.Parameters.AddWithValue("@SourceTable", $srcTable) | Out-Null
    $cmd.Parameters.AddWithValue("@TargetTable", $tgtTable) | Out-Null
    
    $outP = $cmd.Parameters.Add("@LogID", [System.Data.SqlDbType]::BigInt)
    $outP.Direction = [System.Data.ParameterDirection]::Output
    $cmd.ExecuteNonQuery() | Out-Null
    return $outP.Value
}

function Log-ETLEnd($logId, $status, $readCount, $insertCount, $err = $null) {
    $cmd = $dwConn.CreateCommand()
    $cmd.CommandText = "dbo.sp_ETL_Log_End"
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.Parameters.AddWithValue("@LogID", $logId) | Out-Null
    $cmd.Parameters.AddWithValue("@Status", $status) | Out-Null
    $cmd.Parameters.AddWithValue("@RowsRead", $readCount) | Out-Null
    $cmd.Parameters.AddWithValue("@RowsInserted", $insertCount) | Out-Null
    $cmd.Parameters.AddWithValue("@RowsUpdated", 0) | Out-Null
    $cmd.Parameters.AddWithValue("@RowsRejected", 0) | Out-Null
    if ($err) { $cmd.Parameters.AddWithValue("@ErrorMessage", $err) | Out-Null }
    $cmd.ExecuteNonQuery() | Out-Null
}

function Ingest-CsvToStaging($csvFileName, $tableName) {
    $fullPath = Join-Path $DataDir $csvFileName
    if (-not (Test-Path $fullPath)) {
        Write-Host "Fichier introuvable: $fullPath" -ForegroundColor Red
        return
    }

    $logId = Log-ETLStart "Fast BulkLoad $tableName" $csvFileName $tableName
    Write-Host "-> Chargement $csvFileName vers $tableName (Max: $MaxRows lignes)..." -ForegroundColor Yellow

    try {
        # Vidage idempotent
        $truncCmd = $saConn.CreateCommand()
        $truncCmd.CommandText = "TRUNCATE TABLE $tableName;"
        $truncCmd.ExecuteNonQuery() | Out-Null

        $reader = [System.IO.File]::OpenText($fullPath)
        $headerLine = $reader.ReadLine()
        $headers = $headerLine.Split(',')

        $dt = New-Object System.Data.DataTable
        foreach ($h in $headers) {
            $dt.Columns.Add($h.Trim('"'), [string]) | Out-Null
        }

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($saConn)
        $bulk.DestinationTableName = $tableName
        $bulk.BatchSize = 10000
        $bulk.BulkCopyTimeout = 300

        foreach ($h in $headers) {
            $cleanH = $h.Trim('"')
            $bulk.ColumnMappings.Add($cleanH, $cleanH) | Out-Null
        }

        $count = 0
        while (-not $reader.EndOfStream -and $count -lt $MaxRows) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $vals = $line.Split(',')
            if ($vals.Length -ge $headers.Length) {
                $row = $dt.NewRow()
                for ($i = 0; $i -lt $headers.Length; $i++) {
                    $v = $vals[$i].Trim('"').Trim()
                    if ([string]::IsNullOrEmpty($v) -or $v -eq "NA" -or $v -eq "null") {
                        $row[$i] = [DBNull]::Value
                    } else {
                        $row[$i] = $v
                    }
                }
                $dt.Rows.Add($row)
                $count++
            }
        }
        $reader.Close()

        $bulk.WriteToServer($dt)
        $bulk.Close()

        Log-ETLEnd $logId "SUCCESS" $count $count
        Write-Host "   Succès : $count lignes chargées dans $tableName." -ForegroundColor Green
    }
    catch {
        $errMsg = $_.Exception.Message
        Log-ETLEnd $logId "FAILED" 0 0 $errMsg
        Write-Host "   Erreur sur $tableName : $errMsg" -ForegroundColor Red
        throw
    }
}

# 1. Collision
Ingest-CsvToStaging "road_safety_collision-last_5years.csv" "dbo.SA_Collision"

# 2. Véhicules
Ingest-CsvToStaging "road_safety_vehicle-last_5years.csv" "dbo.SA_Vehicle"

# 3. Victimes
Ingest-CsvToStaging "road_safety_casualty-last_5years.csv" "dbo.SA_Casualty"

$saConn.Close()
$dwConn.Close()

Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  INGESTION DES 3 TABLES DE STAGING TERMINEE AVEC SUCCES" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green

# ==============================================================================
# Script d'injection automatique des Mesures DAX & Hiérarchies
# Projet DW_RoadSafety - ESPRIT 2026
# ==============================================================================

try {
    Add-Type -Path "C:\Program Files\WindowsApps\Microsoft.MicrosoftPowerBIDesktop_2.159.1231.0_x64__8wekyb3d8bbwe\bin\Microsoft.AnalysisServices.Server.Core.dll"
    Add-Type -Path "C:\Program Files\WindowsApps\Microsoft.MicrosoftPowerBIDesktop_2.159.1231.0_x64__8wekyb3d8bbwe\bin\Microsoft.AnalysisServices.Server.Tabular.dll"

    $ms = Get-Process -Name 'msmdsrv' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ms) {
        Write-Error "Power BI Desktop n'est pas ouvert ! Veuillez d'abord ouvrir TP_RappRoadSafety.pbids et charger les tables."
        return
    }

    $port = (Get-NetTCPConnection -OwningProcess $ms.Id | Where-Object { $_.State -eq 'Listen' -and $_.LocalAddress -eq '127.0.0.1' }).LocalPort
    $server = New-Object Microsoft.AnalysisServices.Tabular.Server
    $server.Connect("localhost:$port")
    $model = $server.Databases[0].Model

    Write-Host "Connecté avec succès au modèle Power BI actif (Port: $port)" -ForegroundColor Green

    $tblFact = $model.Tables["FACT_COLLISION"]
    if (-not $tblFact) {
        Write-Error "La table FACT_COLLISION n'a pas encore été chargée dans Power BI !"
        return
    }

    # 1. Mesures DAX
    $measures = @(
        @{ Name="Nombre_Collisions"; Expr="COUNTROWS('FACT_COLLISION')"; Fmt="#,##0"; Folder="1. Volume Accidents" },
        @{ Name="Total_Victimes"; Expr="SUM('FACT_COLLISION'[number_of_casualties])"; Fmt="#,##0"; Folder="1. Volume Accidents" },
        @{ Name="Total_Accidents_Graves_KSI"; Expr="CALCULATE(COUNTROWS('FACT_COLLISION'), 'FACT_COLLISION'[est_ksi] = TRUE())"; Fmt="#,##0"; Folder="1. Volume Accidents" },
        @{ Name="Taux_Gravite_KSI_Pct"; Expr="DIVIDE([Total_Accidents_Graves_KSI], [Nombre_Collisions], 0)"; Fmt="0.0 %"; Folder="1. Volume Accidents" },
        
        @{ Name="Cout_Societal_Total"; Expr="SUM('FACT_COLLISION'[cost_societal_gbp])"; Fmt="#,##0 £"; Folder="2. Impact Economique" },
        @{ Name="Cout_Moyen_Par_Accident"; Expr="DIVIDE([Cout_Societal_Total], [Nombre_Collisions], 0)"; Fmt="#,##0.00 £"; Folder="2. Impact Economique" },
        @{ Name="Score_Point_Noir_Total"; Expr="SUM('FACT_COLLISION'[score_point_noir])"; Fmt="#,##0.00"; Folder="2. Impact Economique" },
        
        @{ Name="K_Securite"; Expr="VAR X = 50000000 VAR CurrentCout = [Cout_Societal_Total] RETURN SWITCH(TRUE(), CurrentCout < 0.6 * X, 1, CurrentCout <= 0.9 * X, 0, CurrentCout > 0.9 * X, -1, BLANK())"; Fmt="0"; Folder="3. Indicateurs & Objectifs" }
    )

    foreach ($m in $measures) {
        if ($tblFact.Measures.Contains($m.Name)) {
            $tblFact.Measures.Remove($tblFact.Measures[$m.Name])
        }
        $newM = New-Object Microsoft.AnalysisServices.Tabular.Measure
        $newM.Name = $m.Name
        $newM.Expression = $m.Expr
        $newM.FormatString = $m.Fmt
        $newM.DisplayFolder = $m.Folder
        $tblFact.Measures.Add($newM)
        Write-Host "  [+] Mesure DAX ajoutée : $($m.Name)" -ForegroundColor Cyan
    }

    # 2. Colonne de regroupement sur DIM_TEMPS
    $tblTemps = $model.Tables["DIM_TEMPS"]
    if ($tblTemps -and (-not $tblTemps.Columns.Contains("Annee (groupes)"))) {
        $colGrp = New-Object Microsoft.AnalysisServices.Tabular.CalculatedColumn
        $colGrp.Name = "Annee (groupes)"
        $colGrp.Expression = 'SWITCH(TRUE(), DIM_TEMPS[year] >= 2018 && DIM_TEMPS[year] <= 2020, "2018-2020", DIM_TEMPS[year] >= 2021 && DIM_TEMPS[year] <= 2022, "2021-2022", "Autre")'
        $colGrp.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::String
        $tblTemps.Columns.Add($colGrp)
        Write-Host "  [+] Colonne calculée ajoutée : DIM_TEMPS[Annee (groupes)]" -ForegroundColor Cyan
    }

    # 3. Colonne de nettoyage sur DIM_LIEU
    $tblLieu = $model.Tables["DIM_LIEU"]
    if ($tblLieu -and (-not $tblLieu.Columns.Contains("Milieu_Harmonise"))) {
        $colLieu = New-Object Microsoft.AnalysisServices.Tabular.CalculatedColumn
        $colLieu.Name = "Milieu_Harmonise"
        $colLieu.Expression = 'SWITCH(DIM_LIEU[rural_urban_area], "1", "Urbain", "2", "Rural", "Missing", "Non Spécifié", DIM_LIEU[rural_urban_area])'
        $colLieu.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::String
        $tblLieu.Columns.Add($colLieu)
        Write-Host "  [+] Colonne calculée ajoutée : DIM_LIEU[Milieu_Harmonise]" -ForegroundColor Cyan
    }

    $model.SaveChanges()
    Write-Host "`nSUCCÈS TOTAL : Toutes les mesures DAX et colonnes ont été intégrées dans Power BI !" -ForegroundColor Green
    Write-Host "Vous pouvez maintenant faire 'Enregistrer' (Ctrl+S) dans Power BI sous le nom TP_RappRoadSafety.pbix." -ForegroundColor Yellow
} catch {
    Write-Error $_.Exception.ToString()
}

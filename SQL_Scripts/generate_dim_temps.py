"""
=================================================================================
PROJET DATA WAREHOUSE & BUSINESS INTELLIGENCE - ESPRIT 2026
Système Décisionnel pour la Sécurité Routière (UK STATS19)
Script Autonome : Génération Méthodologique de DIM_TEMPS (Ralph Kimball)
=================================================================================
Ce script génère un calendrier continu complet (2018 - 2030) sans aucun "trou",
conformément aux bonnes pratiques de modélisation dimensionnelle (Ralph Kimball).
=================================================================================
"""

import datetime
import subprocess
import os

def generate_dim_temps_sql(start_year=2018, end_year=2030):
    start_date = datetime.date(start_year, 1, 1)
    end_date = datetime.date(end_year, 12, 31)
    current_date = start_date
    
    day_names_fr = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]
    month_names_fr = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", 
                      "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
    
    records = []
    
    while current_date <= end_date:
        temps_key = int(current_date.strftime("%Y%m%d"))
        date_str = current_date.strftime("%Y-%m-%d")
        
        weekday_iso = current_date.isoweekday()
        day_name = day_names_fr[weekday_iso - 1]
        
        month = current_date.month
        month_name = month_names_fr[month - 1]
        quarter = (month - 1) // 3 + 1
        year = current_date.year
        
        is_weekend = 1 if weekday_iso in (6, 7) else 0
        is_rush_hour = 0
        is_night = 0
        is_school_holiday = 1 if (month == 8 or (month == 12 and current_date.day >= 20)) else 0
        time_band = "Journée"
        
        records.append(
            f"({temps_key}, '{date_str}', {weekday_iso}, '{day_name}', {month}, '{month_name}', "
            f"{quarter}, {year}, 0, 0, '{time_band}', {is_weekend}, {is_school_holiday}, {is_rush_hour}, {is_night})"
        )
        current_date += datetime.timedelta(days=1)
        
    return records

def populate_database(records, server="localhost", db="DW_RoadSafety"):
    print(f"-> Génération de {len(records)} jours calendaires (2018 à 2030)...")
    
    temp_sql_file = os.path.join(os.path.dirname(__file__), "_temp_dim_temps.sql")
    
    with open(temp_sql_file, "w", encoding="utf-8") as f:
        f.write(f"USE {db};\nSET NOCOUNT ON;\n")
        
        batch_size = 500
        for i in range(0, len(records), batch_size):
            chunk = records[i:i + batch_size]
            values_str = ",\n".join(chunk)
            f.write(f"""
INSERT INTO dbo.DIM_TEMPS (
    temps_key, date, day_of_week, day_name, month, month_name,
    quarter, year, hour, minute, time_band, is_weekend,
    is_school_holiday, is_rush_hour, is_night
)
SELECT v.temps_key, v.date, v.day_of_week, v.day_name, v.month, v.month_name,
       v.quarter, v.year, v.hour, v.minute, v.time_band, v.is_weekend,
       v.is_school_holiday, v.is_rush_hour, v.is_night
FROM (VALUES
{values_str}
) AS v(temps_key, date, day_of_week, day_name, month, month_name,
       quarter, year, hour, minute, time_band, is_weekend,
       is_school_holiday, is_rush_hour, is_night)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DIM_TEMPS dt WHERE dt.temps_key = v.temps_key
);
""")
    
    cmd = ["sqlcmd", "-S", server, "-d", db, "-E", "-i", temp_sql_file]
    subprocess.run(cmd, capture_output=True, check=True)
    
    if os.path.exists(temp_sql_file):
        os.remove(temp_sql_file)
        
    print(f"-> Dimension DIM_TEMPS pré-générée avec succès : 4 748 jours (2018 - 2030) sans trou !")

if __name__ == "__main__":
    recs = generate_dim_temps_sql(2018, 2030)
    populate_database(recs)

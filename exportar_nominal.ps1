# =====================================================================
#  REPORTES NOMINALES DE TODOS LOS INDICADORES - SOLO USO LOCAL
#  Para cada indicador guarda privado\<CODIGO>_nominal.csv
#  con TODAS las personas (cumplen y no cumplen) y la columna Condicion.
#    1) Si existe sql\nominal_<CODIGO>.sql, usa esa consulta.
#    2) Si no, busca la tabla TRAMAHIS_..._<CLAVE>_NOMINAL
#       (ej. MC-01.01 -> MC_0101) y exporta todas sus filas.
#  privado\ NUNCA se sube a GitHub.
# =====================================================================
param(
    [string]$Servidor  = "DESKTOP-STSFKEP\SQLEXPRESS",
    [string]$BaseDatos = "DataHIS",
    [string]$Provincia = "2209"          # filtro si la tabla tiene columna provincia
)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path

# Seguridad: privado/ debe estar en .gitignore
$gi = Join-Path $raiz ".gitignore"
if (-not (Test-Path $gi) -or ((Get-Content $gi -Raw) -notmatch "(?m)^privado/")) {
    Add-Content $gi "`r`nprivado/"; Write-Host "Se agrego privado/ a .gitignore" -ForegroundColor Yellow
}
$carpeta = Join-Path $raiz "privado"
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null

function Consultar([string]$sql) {
    $sql = $sql -replace '(?im)^\s*GO\s*$', ''
    $cn  = New-Object System.Data.SqlClient.SqlConnection "Server=$Servidor;Database=$BaseDatos;Integrated Security=True;TrustServerCertificate=True"
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 1800
    $t = New-Object System.Data.DataTable
    try { $cn.Open(); $t.Load($cmd.ExecuteReader()) } finally { $cn.Close() }
    return ,$t
}
function Guardar($t, [string]$codigo) {
    $cols = $t.Columns | ForEach-Object ColumnName
    $filas = foreach ($r in $t.Rows) {
        $o = [ordered]@{}
        foreach ($c in $cols) {
            $v = $r[$c]
            if ($v -is [DBNull]) { $v = "" } elseif ($v -is [DateTime]) { $v = $v.ToString("yyyy-MM-dd") }
            $o[$c] = $v
        }
        [pscustomobject]$o
    }
    $filas | Export-Csv (Join-Path $carpeta "$($codigo)_nominal.csv") -NoTypeInformation -Encoding UTF8
    $viejo = Join-Path $carpeta "$($codigo)_no_cumplen.csv"
    if (Test-Path $viejo) { Remove-Item $viejo }
}

# Indicadores (de datos\indicadores_meta.json, que genera actualizar.ps1)
$codigos = (Get-Content (Join-Path $raiz "datos\indicadores_meta.json") -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_.codigo }

# Tablas nominales disponibles
$tablas = Consultar "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '%NOMINAL%' ORDER BY TABLE_NAME"
$faltan = @()

foreach ($codigo in $codigos) {
    try {
        $archivoSql = Join-Path $raiz "sql\nominal_$codigo.sql"
        if (Test-Path $archivoSql) {
            try {
                $t = Consultar (Get-Content $archivoSql -Raw -Encoding UTF8)
                Guardar $t $codigo
                Write-Host ("{0,-9} {1,6} personas  (sql\nominal_{0}.sql)" -f $codigo, $t.Rows.Count) -ForegroundColor Green
                continue
            } catch {
                Write-Host "$codigo  sql\nominal_$codigo.sql fallo ($($_.Exception.Message)); se usa la tabla NOMINAL" -ForegroundColor Yellow
            }
        }
        $clave = ($codigo -replace '-', '_') -replace '\.', ''          # MC-01.01 -> MC_0101
        $cand = @($tablas.Rows | Where-Object { $_.TABLE_NAME -like "*$clave*" })
        if (-not $cand) { $faltan += $codigo; Write-Host ("{0,-9} sin tabla nominal (*{1}*NOMINAL*)" -f $codigo, $clave) -ForegroundColor Yellow; continue }
        $tab = @($cand | Sort-Object { $_.TABLE_NAME.Length })[0]      # @() evita tomar la 1a columna de la fila
        $nombre = "[$($tab.TABLE_SCHEMA)].[$($tab.TABLE_NAME)]"
        $cols = @((Consultar "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$($tab.TABLE_SCHEMA)' AND TABLE_NAME='$($tab.TABLE_NAME)'").Rows | ForEach-Object { $_.COLUMN_NAME.ToLower() })
        if ($cols -notcontains "numerador") { $faltan += $codigo; Write-Host "$codigo  $nombre no tiene columna 'numerador'" -ForegroundColor Yellow; continue }
        $where = "1 = 1"
        if ($cols -contains "provincia") { $where += " AND provincia LIKE '$Provincia%'" }
        $t = Consultar "SELECT *, CASE WHEN numerador > 0 THEN 'CUMPLE' ELSE 'NO CUMPLE' END AS Condicion FROM $nombre WHERE $where"
        Guardar $t $codigo
        $nNo = @($t.Rows | Where-Object { $_.Condicion -eq 'NO CUMPLE' }).Count
        Write-Host ("{0,-9} {1,6} personas  ({2} no cumplen)  {3}" -f $codigo, $t.Rows.Count, $nNo, $tab.TABLE_NAME) -ForegroundColor Green
    } catch {
        $faltan += $codigo
        Write-Host "$codigo  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($faltan) {
    Write-Host "`nSin reporte: $($faltan -join ', ')" -ForegroundColor Yellow
    Write-Host "Tablas NOMINAL encontradas en $BaseDatos :"
    $tablas.Rows | ForEach-Object { Write-Host "   $($_.TABLE_NAME)" }
}
Write-Host "`nListo (solo local). Recarga la pagina con Ctrl+F5."

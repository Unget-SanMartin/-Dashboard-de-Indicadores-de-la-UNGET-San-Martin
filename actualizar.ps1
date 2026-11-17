# =====================================================================
#  Actualiza la carpeta datos/ desde DataHIS (SQL Server)
#  Uso (desde la carpeta del repositorio):
#     powershell -ExecutionPolicy Bypass -File .\actualizar.ps1
#  Otro servidor:
#     .\actualizar.ps1 -Servidor "OTRO-PC\INSTANCIA"
# =====================================================================
param(
    [string]$Servidor  = "DESKTOP-STSFKEP\SQLEXPRESS",
    [string]$BaseDatos = "DataHIS",
    # Carpetas donde estan los archivos padron_nominal_AAAAMMDD y cnv_AAAAMMDD
    # (se busca tambien en sus subcarpetas). Agrega aqui tu carpeta si es otra.
    [string[]]$CarpetasFuentes = @(
        "C:\HISMINSA\MAESTROS\HIS",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "C:\indicadores-fed"
    )
)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path

function Consultar([string]$archivo) {
    $sql = Get-Content (Join-Path $raiz $archivo) -Raw -Encoding UTF8
    $cn  = New-Object System.Data.SqlClient.SqlConnection "Server=$Servidor;Database=$BaseDatos;Integrated Security=True;TrustServerCertificate=True"
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 900
    $t = New-Object System.Data.DataTable
    try { $cn.Open(); $t.Load($cmd.ExecuteReader()) } finally { $cn.Close() }
    return ,$t
}
function Valor($v) { if ($v -is [DBNull]) { $null } else { $v } }

# ---- 1. Cifras agregadas ---------------------------------------------
$res = Consultar "sql\exportar_indicadores.sql"
$permitidas = "periodo","ubigeo","distrito","microred","eess","renaes","codigo","numerador","denominador"
$extra = $res.Columns | Where-Object { $permitidas -notcontains $_.ColumnName }
if ($extra) { throw "La consulta devuelve columnas no permitidas ($($extra.ColumnName -join ', ')). Solo cifras agregadas." }
# Microred por distrito para las filas sin EESS (indicadores de grano Distrito)
$md = @{}
foreach ($r in (Consultar "sql\exportar_microred_distrito.sql").Rows) {
    $md[([string]$r.ubigeo).Trim()] = [string]$r.microred
}
$cols = foreach ($c in $permitidas) {
    if ($c -eq "microred") {
        @{ Name = "microred"; Expression = {
            $m = Valor $_.microred
            if ([string]::IsNullOrWhiteSpace([string]$m)) { $md[([string](Valor $_.ubigeo)).Trim()] } else { $m }
        } }
    } else { $c }
}
$res | Select-Object $cols |
    Export-Csv (Join-Path $raiz "datos\indicadores.csv") -NoTypeInformation -Encoding UTF8

# ---- 2. Nombres y metas -----------------------------------------------
$met = Consultar "sql\exportar_metas.sql"
$lista = foreach ($r in $met.Rows) {
    [pscustomobject]@{
        codigo            = Valor $r.codigo
        nombre            = Valor $r.nombre
        eje               = Valor $r.eje
        grano             = Valor $r.grano
        meta              = Valor $r.meta
        umbral_en_proceso = Valor $r.umbral_en_proceso
        sentido           = Valor $r.sentido
    }
}
ConvertTo-Json -InputObject @($lista) -Depth 3 |
    Set-Content (Join-Path $raiz "datos\indicadores_meta.json") -Encoding UTF8

# ---- 3. Fecha y fuentes (fechas de corte HISMINSA / PN / CNV) -----------
$ahora = Get-Date
$fecha = $ahora.ToString("dd/MM/yyyy")
$iso   = $ahora.ToString("yyyy-MM-ddTHH:mm:ss")
$fuentes = @()
try {
    foreach ($r in (Consultar "sql\exportar_fuentes.sql").Rows) {
        $fuentes += [pscustomobject]@{ fuente = ([string]$r.fuente).Trim(); corte = ([string]$r.corte).Trim() }
    }
} catch {
    Write-Host "AVISO: no se pudieron leer las fechas de corte ($($_.Exception.Message))." -ForegroundColor Yellow
}
# PN y CNV: la fecha de corte sale del NOMBRE del archivo mas reciente
#   padron_nominal_20261019.xlsx -> 19/10/2026     cnv_20261013.xlsx -> 13/10/2026
# Si no se encuentra el archivo, se queda la fecha calculada de los datos.
function FechaDeArchivo([string]$filtro, [string]$regex) {
    $mejor = $null
    foreach ($c in $CarpetasFuentes) {
        if (-not (Test-Path $c)) { continue }
        foreach ($a in (Get-ChildItem -Path $c -Filter $filtro -File -Recurse -Depth 3 -ErrorAction SilentlyContinue)) {
            if ($a.BaseName -match $regex) {
                $d = [datetime]::MinValue
                if ([datetime]::TryParseExact($Matches[1], "yyyyMMdd", $null, "None", [ref]$d) -and
                    $d -le (Get-Date) -and ($null -eq $mejor -or $d -gt $mejor.fecha)) {
                    $mejor = [pscustomobject]@{ fecha = $d; archivo = $a.Name }
                }
            }
        }
    }
    return $mejor
}
foreach ($p in @(@{ f = "PN";  filtro = "padron_nominal_*"; rx = '^padron_nominal_(20\d{6})' },
                 @{ f = "CNV"; filtro = "cnv_*";            rx = '^cnv_(20\d{6})' })) {
    $arc = FechaDeArchivo $p.filtro $p.rx
    if ($arc) {
        $fuentes = @($fuentes | Where-Object { $_.fuente -ne $p.f }) +
                   [pscustomobject]@{ fuente = $p.f; corte = $arc.fecha.ToString("dd/MM/yyyy") }
        Write-Host ("{0}: fecha de corte tomada del archivo {1}" -f $p.f, $arc.archivo) -ForegroundColor DarkGray
    } else {
        Write-Host ("AVISO: no se encontro ningun archivo {0} en las carpetas de fuentes; se usa la fecha de los datos." -f $p.filtro) -ForegroundColor Yellow
    }
}
$orden = @{ HISMINSA = 1; PN = 2; CNV = 3 }
$fuentes = @($fuentes | Sort-Object { $orden[$_.fuente] })

foreach ($req in "HISMINSA","PN","CNV") {
    if (-not ($fuentes | Where-Object { $_.fuente -eq $req })) {
        Write-Host "AVISO: no se encontro la fecha de corte de $req (revisa sql\exportar_fuentes.sql)" -ForegroundColor Yellow
    }
}
ConvertTo-Json -InputObject ([ordered]@{ actualizado = $fecha; fecha_hora = $iso; fuentes = @($fuentes) }) -Depth 4 |
    Set-Content (Join-Path $raiz "datos\actualizado.json") -Encoding UTF8

Write-Host "Listo: $($res.Rows.Count) filas y $($met.Rows.Count) indicadores ($fecha)." -ForegroundColor Green
if ($fuentes.Count) { Write-Host ("Fuentes: " + (($fuentes | ForEach-Object { "$($_.fuente) ($($_.corte))" }) -join " - ")) -ForegroundColor Green }
Write-Host "Revisa la pagina localmente y luego haz Commit + Push en GitHub Desktop."

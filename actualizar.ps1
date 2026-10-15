# =====================================================================
#  Actualiza la carpeta datos/ desde DataHIS (SQL Server)
#  Uso (desde la carpeta del repositorio):
#     powershell -ExecutionPolicy Bypass -File .\actualizar.ps1
#  Otro servidor:
#     .\actualizar.ps1 -Servidor "OTRO-PC\INSTANCIA"
# =====================================================================
param(
    [string]$Servidor  = "DESKTOP-STSFKEP\SQLEXPRESS",
    [string]$BaseDatos = "DataHIS"
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
$res | Select-Object $permitidas |
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

# ---- 3. Fecha -----------------------------------------------------------
$ahora = Get-Date
$fecha = $ahora.ToString("dd/MM/yyyy")
$iso   = $ahora.ToString("yyyy-MM-ddTHH:mm:ss")
Set-Content (Join-Path $raiz "datos\actualizado.json") "{ `"actualizado`": `"$fecha`", `"fecha_hora`": `"$iso`" }" -Encoding UTF8

Write-Host "Listo: $($res.Rows.Count) filas y $($met.Rows.Count) indicadores ($fecha)." -ForegroundColor Green
Write-Host "Revisa la pagina localmente y luego haz Commit + Push en GitHub Desktop."

# =====================================================================
#  ACTUALIZA TODO Y VERIFICA ANTES DE PUBLICAR
#  Uso (desde la carpeta del repositorio):
#     powershell -ExecutionPolicy Bypass -File .\actualizar_todo.ps1
#  1) actualizar.ps1        -> datos\ (lo que se publica)
#  2) exportar_nominal.ps1  -> privado\ (solo local)
#  3) Controles: microred vacia, indicadores faltantes, caidas de
#     denominador frente a la actualizacion anterior, nominales faltantes.
# =====================================================================
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $raiz

Write-Host "== 1/3 Cifras agregadas (actualizar.ps1) ==" -ForegroundColor Cyan
try { & (Join-Path $raiz "actualizar.ps1") }
catch { Write-Host "`nFALLO actualizar.ps1: $($_.Exception.Message)" -ForegroundColor Red; Write-Host "NO publiques. Corrige el error y vuelve a correr." -ForegroundColor Red; exit 1 }

Write-Host "`n== 2/3 Listas nominales (exportar_nominal.ps1) ==" -ForegroundColor Cyan
try { & (Join-Path $raiz "exportar_nominal.ps1") }
catch { Write-Host "`nFALLO exportar_nominal.ps1: $($_.Exception.Message)" -ForegroundColor Yellow; Write-Host "Las cifras publicas se generaron; las descargas locales pueden estar desactualizadas." -ForegroundColor Yellow }

Write-Host "`n== 3/3 Verificacion ==" -ForegroundColor Cyan
$errores = @(); $avisos = @()
$d     = @(Import-Csv (Join-Path $raiz "datos\indicadores.csv"))
$metas = @(Get-Content (Join-Path $raiz "datos\indicadores_meta.json") -Raw -Encoding UTF8 | ConvertFrom-Json)
$cods  = @($metas | ForEach-Object { $_.codigo })

# a) Filas sin microred
$sinMr = @($d | Where-Object { [string]::IsNullOrWhiteSpace($_.microred) })
if ($sinMr.Count) {
    $u = ($sinMr | ForEach-Object { "$($_.ubigeo) $($_.distrito)".Trim() } | Sort-Object -Unique) -join ", "
    $errores += "$($sinMr.Count) filas sin microred (distritos: $u). Agregalos a dbo.MICRORED_DISTRITO."
}

# b) Indicadores sin datos
$presentes = @($d | ForEach-Object codigo | Sort-Object -Unique)
$faltan = @($cods | Where-Object { $presentes -notcontains $_ })
if ($faltan.Count) { $errores += "Indicadores sin ninguna fila: $($faltan -join ', ')" }

# c) Caida de denominador frente a la actualizacion anterior (mismo indicador y mes)
$actual = @{}
foreach ($r in $d) {
    $k = "$($r.codigo)|$($r.periodo)"
    $actual[$k] = [double]$actual[$k] + [double]($r.denominador -replace ',', '.')
}
$priv = Join-Path $raiz "privado"; New-Item -ItemType Directory -Force -Path $priv | Out-Null
$control = Join-Path $priv "control_actualizacion.json"
if (Test-Path $control) {
    $prev = Get-Content $control -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $prev.PSObject.Properties) {
        $antes = [double]$p.Value; $ahora = [double]$actual[$p.Name]
        if ($antes -ge 10 -and $ahora -lt $antes * 0.9) {
            $avisos += ("{0}: denominador bajo de {1} a {2} ({3:N0}%)" -f $p.Name.Replace('|', ' '), $antes, $ahora, (($ahora - $antes) / $antes * 100))
        }
    }
} else { $avisos += "Primera verificacion: se guarda la referencia para comparar la proxima vez." }

# d) Nominales locales
$sinNom = @($cods | Where-Object { -not (Test-Path (Join-Path $priv "$($_)_nominal.csv")) })
if ($sinNom.Count) { $avisos += "Sin lista nominal local: $($sinNom -join ', ')" }

# Resumen
Write-Host ("Filas: {0}   Indicadores con datos: {1} de {2}   Periodos: {3}" -f $d.Count, ($cods.Count - $faltan.Count), $cods.Count, (@($d | ForEach-Object periodo | Sort-Object -Unique) -join ', '))
foreach ($a in $avisos)  { Write-Host "AVISO: $a" -ForegroundColor Yellow }
foreach ($e in $errores) { Write-Host "ERROR: $e" -ForegroundColor Red }

if ($errores.Count) {
    Write-Host "`nNO publiques todavia: corrige los errores y vuelve a correr." -ForegroundColor Red
    exit 1
}
# Solo se guarda la referencia si no hubo errores
$actual | ConvertTo-Json | Set-Content $control -Encoding UTF8
if ($avisos.Count -and (Test-Path $control)) { Write-Host "`nRevisa los avisos. Si todo esta bien:" -ForegroundColor Yellow }
Write-Host "`nTodo OK. Revisa en localhost:8000 (python -m http.server) y luego Commit + Push en GitHub Desktop." -ForegroundColor Green

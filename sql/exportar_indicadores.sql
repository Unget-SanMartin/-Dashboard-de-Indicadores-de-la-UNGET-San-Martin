/* =====================================================================
   Resultados FED para la página web (GitHub Pages)
   Misma granularidad que VW_FED_RESULTADO: indicador x mes x EESS
   (o x distrito, en los indicadores distritales).
   Solo conteos: numerador y denominador. Sin DNI ni nombres de personas.
   ===================================================================== */

DECLARE @Red varchar(100) = 'SAN MART_N';   -- "_" acepta MARTIN o MARTÍN

SELECT
    periodo     = CONVERT(char(7), R.Periodo, 126),
    ubigeo      = ISNULL(R.Ubigeo, ''),
    distrito    = ISNULL(U.Distrito, ''),
    microred    = ISNULL(E.MicroRed, ''),
    eess        = ISNULL(E.EESS_nombre, ''),
    renaes      = ISNULL(CAST(R.EESS_renaes AS varchar(20)), ''),
    codigo      = R.Indicador_Codigo,
    numerador   = ISNULL(R.Numerador, 0),
    denominador = ISNULL(R.Denominador, 0)
FROM DataHIS.dbo.VW_FED_RESULTADO R
LEFT JOIN (
    SELECT EESS_renaes,
           EESS_nombre = MAX(EESS_nombre),
           Red         = MAX(Red),
           MicroRed    = MAX(MicroRed)
    FROM DataHIS.dbo.VW_DIM_FED_EESS
    GROUP BY EESS_renaes
) E ON E.EESS_renaes = R.EESS_renaes
LEFT JOIN DataHIS.dbo.VW_DIM_FED_Ubigeo U
    ON U.Ubigeo = R.Ubigeo
WHERE
      (R.EESS_renaes IS NOT NULL AND E.Red       LIKE '%' + @Red + '%')
   OR (R.EESS_renaes IS NULL     AND U.Provincia LIKE '%' + @Red + '%')
ORDER BY codigo, periodo, distrito, microred;

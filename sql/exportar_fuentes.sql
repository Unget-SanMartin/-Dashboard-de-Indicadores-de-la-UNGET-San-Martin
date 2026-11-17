-- =====================================================================
--  Fecha de corte de cada fuente, calculada de los mismos datos
--  (se actualiza sola cada vez que cargas la trama, el PN o el CNV)
--   HISMINSA : ultima FECHA_REG (fecha de registro) de dbo.HIS
--   PN       : ultima Fecha_mod (o Fecha_creacion) de dbo.PN_FED
--   CNV      : fecha_actualizacion_data de dbo.CNV (o la ultima fe_crea)
--  Se ignoran fechas futuras por si hay registros mal digitados.
-- =====================================================================
SET NOCOUNT ON;
DECLARE @hoy date = CAST(GETDATE() AS date);

SELECT fuente, CONVERT(char(10), corte, 103) AS corte   -- dd/mm/aaaa
FROM (
    SELECT 1 AS orden, 'HISMINSA' AS fuente,
           (SELECT MAX(FECHA_REG) FROM DataHIS.dbo.HIS WHERE FECHA_REG <= @hoy) AS corte
    UNION ALL
    SELECT 2, 'PN',
           (SELECT MAX(CAST(COALESCE(Fecha_mod, Fecha_creacion) AS date))
              FROM DataHIS.dbo.PN_FED
             WHERE COALESCE(Fecha_mod, Fecha_creacion) < DATEADD(day, 1, @hoy))
    UNION ALL
    SELECT 3, 'CNV',
           COALESCE(
             (SELECT MAX(f) FROM (
                 SELECT CAST(COALESCE(TRY_CONVERT(datetime, fecha_actualizacion_data, 103),
                                      TRY_CONVERT(datetime, fecha_actualizacion_data, 120),
                                      TRY_CONVERT(datetime, fecha_actualizacion_data, 126),
                                      TRY_CONVERT(datetime, fecha_actualizacion_data)) AS date) AS f
                 FROM DataHIS.dbo.CNV) x
              WHERE f <= @hoy),
             (SELECT MAX(CAST(fe_crea AS date)) FROM DataHIS.dbo.CNV WHERE fe_crea < DATEADD(day, 1, @hoy)))
) t
WHERE corte IS NOT NULL
ORDER BY orden;

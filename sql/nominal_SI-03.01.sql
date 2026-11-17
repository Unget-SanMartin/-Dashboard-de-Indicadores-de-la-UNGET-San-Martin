/* =====================================================================
   Reporte nominal SI-03.01 (solo uso local; lo usa exportar_nominal.ps1)
   Adolescentes mujeres 12-17 años atendidas en EESS I-1 a I-4 del
   Gobierno Regional, con dosaje de Hb EL MISMO DÍA de su atención.

   Lee la tabla que deja el script de la DIRESA
   (TRAMAHIS_FED2025_26_SI_0301_NOMINAL); no la modifica.
   Agrega:
     - fecha_hb_en_el_mes : primer dosaje de Hb (85018, 85018.01, 85031)
                            de la adolescente en el mismo mes, si lo tuvo
                            en otro día (sirve para explicar por qué no cumple)
     - Condicion          : CUMPLE / NO CUMPLE
   Ejecuta primero FED_2025_26_SI-03.01_JCAR_okok.sql.
   ===================================================================== */
SET NOCOUNT ON;

IF OBJECT_ID(N'tempdb..#hb', N'U') IS NOT NULL DROP TABLE #hb;
SELECT CONVERT(nvarchar(15), Numero_Documento_Paciente)          AS num_doc,
       CONVERT(date, fecha_atencion)                             AS fecha_hb
INTO #hb
FROM DataHIS.dbo.T_CONSOLIDADO_NUEVA_TRAMA_HISMINSA
WHERE Codigo_Item IN ('85018', '85018.01', '85031')
  AND Anio = 2026
GROUP BY Numero_Documento_Paciente, CONVERT(date, fecha_atencion);

CREATE INDEX ix_hb ON #hb (num_doc, fecha_hb);

SELECT t.*,
       ( SELECT MIN(h.fecha_hb)
           FROM #hb h
          WHERE h.num_doc = t.num_doc
            AND CONVERT(char(6), h.fecha_hb, 112) = t.Periodo )   AS fecha_hb_en_el_mes,
       CASE WHEN t.numerador > 0 THEN 'CUMPLE' ELSE 'NO CUMPLE' END AS Condicion
FROM DataHIS.dbo.TRAMAHIS_FED2025_26_SI_0301_NOMINAL t
WHERE t.provincia LIKE '2209%';

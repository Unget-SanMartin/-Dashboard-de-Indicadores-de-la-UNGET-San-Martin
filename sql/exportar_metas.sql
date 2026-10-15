/* Nombres, ejes, metas y grano de los indicadores (DIM_FED_Indicador).
   Las metas vienen como fracción (0.434 = 43.4%); la página las convierte. */
SELECT
    codigo            = Indicador_Codigo,
    nombre            = Indicador_Nombre,
    eje               = Eje,
    grano             = Grano_Origen,
    meta              = Meta,
    umbral_en_proceso = Umbral_En_Proceso,
    sentido           = Sentido
FROM DataHIS.dbo.DIM_FED_Indicador
ORDER BY Eje, Indicador_Codigo;

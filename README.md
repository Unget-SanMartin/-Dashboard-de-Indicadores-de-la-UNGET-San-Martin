# Indicadores FED 2025-26 — Red San Martín

Tablero web de los indicadores FED 2025-26 de la Red de Salud San Martín y sus microredes, publicado con GitHub Pages. Mismo formato que el dashboard UNGET: filtros por periodo, distrito y MicroRed, listado de indicadores con su estado y puntaje por MicroRed.

Los datos salen de las vistas FED de DataHIS (`VW_FED_RESULTADO`, `VW_DIM_FED_EESS`, `VW_DIM_FED_Ubigeo`, `DIM_FED_Indicador`) y se publican **solo como conteos** (numerador y denominador por indicador, mes y establecimiento o distrito). No hay base de datos en línea ni datos nominales.

## Contenido

```
├── index.html                    Página principal del tablero
├── detalle.html                  Detalle de un indicador (se abre al tocarlo)
├── comun.js / estilos.css        Código y estilos compartidos
├── logo-unget.jpg                Logo del encabezado
├── datos/
│   ├── config.json               Título, red y aviso de datos de ejemplo
│   ├── indicadores.csv           Numerador y denominador por registro (lo genera actualizar.ps1)
│   ├── indicadores_meta.json     Nombres, ejes y metas (lo genera actualizar.ps1)
│   └── actualizado.json          Fecha de actualización (lo genera actualizar.ps1)
├── sql/
│   ├── exportar_indicadores.sql  VW_FED_RESULTADO con distrito, MicroRed y EESS
│   └── exportar_metas.sql        DIM_FED_Indicador
├── actualizar.ps1                Ejecuta ambas consultas y regenera datos/
└── .gitignore
```

## Actualización

1. Actualiza DataHIS como siempre (padrón, CNV, scripts de indicadores).
2. En la carpeta del repositorio:
   ```
   powershell -ExecutionPolicy Bypass -File .\actualizar.ps1
   ```
3. La primera vez, cambia `"datos_de_ejemplo": true` a `false` en `datos/config.json`.
4. Commit y Push (GitHub Desktop). La página se actualiza en uno o dos minutos.

## Reglas del semáforo

Se usan la meta, el umbral y el sentido de `DIM_FED_Indicador`:

| Estado | Indicador normal | Indicador donde menos es mejor (sentido descendente) |
|---|---|---|
| Cumple | avance ≥ meta | avance ≤ meta |
| En proceso | avance ≥ umbral | avance ≤ umbral |
| No cumple | el resto | el resto |

Si un indicador no tiene `Umbral_En_Proceso`, se usa el 80 % de la meta (`factor_en_proceso` en `config.json`).

Los indicadores calculados por distrito (sin EESS) aparecen como "Sin MicroRed". El puntaje de cada MicroRed es registros que cumplen ÷ registros evaluados × 100.

## Filtro de red

`sql/exportar_indicadores.sql` filtra con `@Red = 'SAN MART_N'`: por el campo `Red` de la vista de EESS para los indicadores por establecimiento, y por `Provincia` para los indicadores por distrito. Ajusta esa línea si los nombres en tus vistas son distintos.

## Publicar con GitHub Pages

**Settings → Pages → Branch: `main` / `(root)` → Save.** Para probar en la computadora usa Live Server de VS Code o `python -m http.server` (abrir `index.html` con doble clic no carga los datos).

/* =====================================================================
   Reglas para las columnas "Qué pide el indicador" y "Por qué no cumple"
   de los reportes nominales (descargas ⬇ en detalle.html).

   Por indicador:
   - pide:      texto de la columna "Qué pide el indicador".
   - criterios: [columna, etiqueta]. Si la columna vale 0, la etiqueta
                aparece en "Falta: ...".
   - etapa:     (opcional) columna cuyo número inicial dice cuántas etapas
                se exigen (ej. "2. Hasta 2 meses..." = etapas 1 y 2).
   - etapas:    lista de etapas; cada una es una lista de [columna, etiqueta].
   - fuera:     [columna, motivo, valor]. Solo para filas con denominador = 0:
                la primera columna que tiene ese valor (por defecto 0)
                da el motivo de "No entra".
   - motivo:    (opcional) función (fila) => texto, para casos especiales.

   Los textos se basan en las fichas técnicas (versión nov. 2026).
   Ojo: algunas fichas usan otro código que el dashboard:
     dashboard SI-02.01..04 = ficha SI-04.01..04 (hierro en niños)
     dashboard SI-03.01..02 = ficha SI-05.01..02 (adolescentes)
   Los textos se pueden editar libremente.
   ===================================================================== */
const REGLAS = {
  "MC-01.01": {
    pide: "Gestante con parto institucional que recibió el paquete priorizado: exámenes del 1er trimestre (Hb, sífilis, VIH, bacteriuria, perfil obstétrico), APN por trimestre (1 en el 1er, 2 en el 2do, 3 en el 3ro) y 5 entregas de sulfato ferroso",
    criterios: [
      ["numerador_Dosaje_hb", "Dosaje de Hb"], ["numerador_Tamizaje_sifilis", "Tamizaje de sífilis"],
      ["numerador_Tamizaje_VIH", "Tamizaje de VIH"], ["numerador_Tamizaje_bacteriuria", "Tamizaje de bacteriuria"],
      ["numerador_perfil_obstetrico", "Perfil obstétrico"],
      ["numerador_1trim_1apn", "1er APN del 1er trimestre"],
      ["numerador_2trim_1apn", "1er APN del 2do trimestre"], ["numerador_2trim_2apn", "2do APN del 2do trimestre"],
      ["numerador_3trim_1apn", "1er APN del 3er trimestre"], ["numerador_3trim_2apn", "2do APN del 3er trimestre"],
      ["numerador_3trim_3apn", "3er APN del 3er trimestre"],
      ["numerador_sulfato1", "Sulfato ferroso (entrega 1)"], ["numerador_sulfato2", "Sulfato ferroso (entrega 2)"],
      ["numerador_sulfato3", "Sulfato ferroso (entrega 3)"], ["numerador_sulfato4", "Sulfato ferroso (entrega 4)"],
      ["numerador_sulfato5", "Sulfato ferroso (entrega 5)"]
    ]
  },
  "MC-02.01": {
    pide: "Niña/niño de 30 días a 11 meses con el paquete integrado según su edad: DNI emitido hasta los 30 días de nacido, vacunas antineumocócica, antipolio, pentavalente y rotavirus según esquema, hierro en gotas a los 4 meses, dosaje de Hb a los 6 meses y suplementación o tratamiento con hierro de 6 a 11 meses",
    criterios: [
      ["num_DNIemision30d", "DNI emitido hasta los 30 días de nacido"],
      ["num_vac_antineumococica", "Vacuna antineumocócica"], ["num_vac_antipolio", "Vacuna antipolio"],
      ["num_vac_pentavalente", "Vacuna pentavalente"], ["num_vac_rotavirus", "Vacuna rotavirus"],
      ["num_esq4M", "Hierro en gotas a los 4 meses (110 a 130 días)"],
      ["num_dosaje_Hb", "Dosaje de Hb a los 6 meses"],
      ["num_esq6M", "Suplementación o tratamiento con hierro de 6 a 11 meses"]
    ]
  },
  "MC-03.01": {
    pide: "Niña/niño de 59 días con BCG y HVB dentro de las 24 horas de nacido, 3 controles CRED hasta los 21 días (1ro entre el día 3 y 6, luego cada 7 días como mínimo) y tamizaje neonatal entre el 2do y 6to día",
    criterios: [
      ["numerador_vacuna_BCG", "Vacuna BCG en las 1as 24 horas"], ["numerador_vacuna_HVB", "Vacuna HVB en las 1as 24 horas"],
      ["numerador_CRED_Rn1", "CRED RN 1"], ["numerador_CRED_Rn2", "CRED RN 2"], ["numerador_CRED_Rn3", "CRED RN 3"],
      ["numerador_Tamizaje_neo", "Tamizaje neonatal (día 2 a 6)"]
    ]
  },
  "SI-01.01": {
    pide: "Gestante atendida en EESS I-1 a I-4 del Gobierno Regional que recibe su primera atención prenatal en el 1er trimestre (antes de las 14 semanas)",
    criterios: [["numerador_1trim", "1ra APN en el 1er trimestre"]],
    motivo: r => r.numerador_2trim === "1" ? "Su 1ra APN fue en el 2do trimestre; debía ser antes de las 14 semanas"
               : r.numerador_3trim === "1" ? "Su 1ra APN fue en el 3er trimestre; debía ser antes de las 14 semanas"
               : null
  },
  "SI-01.02": {
    pide: "Gestante con anemia (Hb en APN) e inicio de tratamiento, que continúa el tratamiento con su control de Hb según el tiempo transcurrido: 1 mes = 2do tratamiento + Hb; 2 meses = además 3er tratamiento + Hb; 3 meses = además 4to tratamiento",
    etapa: "Entregas_Mes",
    etapas: [
      [["numerador_trat2", "2do tratamiento"], ["numerador_Hb2", "Hb de control 2"]],
      [["numerador_trat3", "3er tratamiento"], ["numerador_Hb3", "Hb de control 3"]],
      [["numerador_trat4", "4to tratamiento"]]
    ],
    fuera: [
      ["denominador_apn_hb1", "APN sin dosaje de Hb"],
      ["denominador_apn_hb1_Dx", "Hb de la APN sin diagnóstico de anemia"],
      ["denominador_apn_Hb1_Dx_trat1", "Con anemia pero sin inicio de tratamiento"]
    ]
  },
  "SI-01.03": {
    pide: "Mujer con parto a término, sin anemia en la gestación, que recibió las entregas de sulfato ferroso más ácido fólico y los dosajes de Hb de control según el trimestre de su 1er dosaje de Hb",
    criterios: [
      ["numerador_suplementacion1", "Suplementación (entrega 1)"], ["numerador_suplementacion2", "Suplementación (entrega 2)"],
      ["numerador_suplementacion3", "Suplementación (entrega 3)"], ["numerador_suplementacion4", "Suplementación (entrega 4)"],
      ["numerador_suplementacion5", "Suplementación (entrega 5)"],
      ["numerador_Hb2", "Hb de control 2"], ["numerador_Hb3", "Hb de control 3"]
    ],
    fuera: [["denominador_Hb1", "Sin dosaje de Hb al inicio de la gestación"]]
  },
  "SI-02.01": {
    pide: "Niña/niño de 6 meses (SIS o sin seguro, no prematuro ni bajo peso) con 1 entrega de hierro a los 4 meses y dosaje de Hb a los 6 meses",
    criterios: [["numerador_hierro4m", "Hierro a los 4 meses"], ["numerador_Hb6m", "Dosaje de Hb a los 6 meses"]]
  },
  "SI-02.02": {
    pide: "Niña/niño prematuro y/o con bajo peso al nacer, de 6 meses y sin anemia, con hierro a los 30 días y entre el 3er y 4to mes, y dosajes de Hb a los 30 días, a los 3 meses de iniciada la suplementación y a los 6 meses",
    criterios: [
      ["numerador_hierro30d", "Hierro a los 30 días"], ["numerador_hierro4m", "Hierro a los 4 meses"],
      ["numerador_Hb30d", "Hb a los 30 días"], ["numerador_Hb4m", "Hb a los 4 meses"], ["numerador_Hb6m", "Hb a los 6 meses"]
    ]
  },
  "SI-02.03": {
    pide: "Niña/niño de 12 meses con anemia diagnosticada a los 6 meses que recibió 3 entregas de tratamiento con hierro (1ra el día del diagnóstico, cada 25-70 días) y 4 dosajes de Hb de control (a 1, 2, 3 y 6 meses de iniciado)",
    criterios: [
      ["numerador_Hierro_Trat1", "Tratamiento con hierro (entrega 1)"], ["numerador_Hierro_trat2", "Tratamiento con hierro (entrega 2)"],
      ["numerador_Hierro_trat3", "Tratamiento con hierro (entrega 3)"],
      ["numerador_Hb7m", "Hb a los 7 meses"], ["numerador_Hb8m", "Hb a los 8 meses"],
      ["numerador_Hb9m", "Hb a los 9 meses"], ["numerador_Hb12m", "Hb a los 12 meses"]
    ],
    fuera: [
      ["denominador_Hb6m", "Sin dosaje de Hb a los 6 meses"],
      ["denominador_Hb6m_Dx", "Hb de los 6 meses sin anemia"]
    ]
  },
  "SI-02.04": {
    pide: "Niña/niño de 12 meses sin anemia a los 6 meses con suplementación preventiva (2 entregas de SF/PO, o 6 de micronutrientes, o 3 combinadas; la 1ra el día del dosaje de los 6 meses) y dosajes de Hb a los 3 y 6 meses de iniciada",
    criterios: [
      ["numerador_suplementacion_inicio", "Inicio de suplementación"],
      ["numerador_suplementacion_continuacion", "Continuación de suplementación"],
      ["numerador_Hb9m", "Hb a los 9 meses (3 meses de iniciada)"], ["numerador_Hb12m", "Hb a los 12 meses (6 meses de iniciada)"]
    ],
    fuera: [
      ["denominador_Hb6m", "Sin dosaje de Hb a los 6 meses"],
      ["denominador_Hb6m_Dx", "Con anemia a los 6 meses (corresponde al SI-02.03)", "1"],
      ["denominador_Hb6m_7m_12m_Dx", "Con diagnóstico de anemia entre los 7 y 12 meses", "1"]
    ]
  },
  "SI-03.01": {
    pide: "Adolescente mujer de 12 a 17 años atendida (por cualquier motivo) en EESS I-1 a I-4 del Gobierno Regional, con dosaje de Hb el mismo día de su atención",
    criterios: [],
    // fecha_hb_en_el_mes la agrega sql\nominal_SI-03.01.sql
    motivo: r => {
      const f = v => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(v ?? "")); return m ? `${m[3]}/${m[2]}/${m[1]}` : v; };
      if (r.fecha_hb_en_el_mes) return `Tuvo dosaje de Hb el ${f(r.fecha_hb_en_el_mes)}, pero no el mismo día de su atención (${f(r.fecha_atendida)})`;
      if ("fecha_hb_en_el_mes" in r) return `Atendida el ${f(r.fecha_atendida)} sin dosaje de Hb (no tiene Hb en todo el mes)`;
      return `Atendida el ${f(r.fecha_atendida)} sin dosaje de Hb ese mismo día`;
    }
  },
  "SI-03.02": {
    pide: "Adolescente mujer de 12 a 17 años sin anemia en su 1er dosaje de Hb que, ese mismo día, recibe hierro más ácido fólico y consejería (alimentación saludable o nutricional), y a los 3 meses tiene un nuevo dosaje de Hb",
    criterios: [
      ["numerador_suplementacion", "Hierro más ácido fólico el día del dosaje"], ["numerador_consejeria", "Consejería en alimentación o nutricional"],
      ["numerador_dosaje_3m", "Dosaje de Hb a los 3 meses"]
    ]
  },
  "VI-01.01": {
    pide: "Gestante con APN en EESS I-1 a I-4 y tamizaje de violencia (96150.01), con detección positiva (R456 o Z13.3) el mismo día y en el mismo EESS",
    criterios: [],
    motivo: r => "Tiene tamizaje de violencia, pero sin detección positiva (R456 o Z13.3) ese día",
    fuera: [["denominador_tamizaje", "APN sin tamizaje de violencia registrado"]]
  },
  "VI-01.02": {
    pide: "Gestante con detección positiva y diagnóstico de violencia que recibe 2 consultas de salud mental y 6 psicoterapias (la 1ra hasta 30 días del diagnóstico, luego cada 3 a 30 días); se exige lo que corresponde a los meses transcurridos desde el diagnóstico",
    etapa: "Entrega_Dx",
    etapas: [
      [["numerador_Csm1", "Consulta de salud mental 1"], ["numerador_psicoterapia1", "Psicoterapia 1"]],
      [["numerador_Csm2", "Consulta de salud mental 2"], ["numerador_psicoterapia2", "Psicoterapia 2"]],
      [["numerador_psicoterapia3", "Psicoterapia 3"]],
      [["numerador_psicoterapia4", "Psicoterapia 4"]],
      [["numerador_psicoterapia5", "Psicoterapia 5"]],
      [["numerador_psicoterapia6", "Psicoterapia 6"]]
    ]
  }
};

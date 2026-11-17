# -*- coding: utf-8 -*-
"""
Agrega a cada privado/<CODIGO>_nominal.csv las columnas
  "Qué pide el indicador" y "Por qué no cumple"
y lo deja igual que la descarga "Descargar todos" del dashboard:
  - separado por punto y coma, con BOM (abre bien en Excel)
  - DNI/documentos como texto (no pierden ceros)
  - columnas nuevas justo después de Condicion
  - orden: no cumplen, cumplen, y al final los que no entran al denominador
Las reglas están en reglas_nominal.json. Lo llama exportar_nominal.ps1.
Uso manual:  python motivos_nominal.py  [carpeta del proyecto]
"""
import csv, json, os, re, sys, glob

csv.field_size_limit(10 ** 8)
try:
    sys.stdout.reconfigure(errors="replace")
except Exception:
    pass
RAIZ = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)))
COL_PIDE, COL_MOTIVO = "Qué pide el indicador", "Por qué no cumple"

ETIQ = {"examenes1trim": "Exámenes del 1er trimestre", "apn": "Atenciones prenatales", "sulfato": "Sulfato ferroso",
        "dosaje_hb": "Dosaje de Hb", "tamizaje_sifilis": "Tamizaje de sífilis", "tamizaje_vih": "Tamizaje de VIH",
        "tamizaje_bacteriuria": "Tamizaje de bacteriuria", "perfil_obstetrico": "Perfil obstétrico"}
ORD = ["", "1er", "2do", "3er", "4to", "5to", "6to"]
PREF = re.compile(r"^(numerador|num|cumple|flag)_", re.I)


def es_no(v):
    return re.fullmatch(r"(0|no|n|false|no cumple)", str(v or "").strip(), re.I) is not None


def es_si_no(v):
    return re.fullmatch(r"(0|1|si|sí|no|s|n|true|false)", str(v or "").strip(), re.I) is not None


def fecha(v):
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})", str(v or ""))
    return f"{m.group(3)}/{m.group(2)}/{m.group(1)}" if m else str(v or "")


def etiqueta(c):
    s = PREF.sub("", c)
    if s.lower() in ETIQ:
        return ETIQ[s.lower()]
    m = re.fullmatch(r"(\d)trim_(\d)apn", s, re.I)
    if m:
        return f"{ORD[int(m.group(2))]} APN del {ORD[int(m.group(1))]} trimestre"
    m = re.fullmatch(r"(?:sulfato|sultafo)_?(\d+)", s, re.I)
    if m:
        return f"Sulfato ferroso (entrega {m.group(1)})"
    s = re.sub(r"(\d)([a-z])", r"\1 \2", re.sub(r"([a-záéíóú])(\d)", r"\1 \2", s.replace("_", " "), flags=re.I), flags=re.I).strip()
    return s[:1].upper() + s[1:]


def juntar(etqs):
    """'Sulfato (entrega 2); Sulfato (entrega 3)' -> 'Sulfato (entregas 2, 3)'"""
    out, grupos = [], {}
    for e in etqs:
        m = re.fullmatch(r"(.*) \(entrega (\d+)\)", e)
        if not m:
            out.append(e); continue
        if m.group(1) not in grupos:
            grupos[m.group(1)] = []; out.append(("g", m.group(1)))
        grupos[m.group(1)].append(m.group(2))
    txt = []
    for x in out:
        if isinstance(x, tuple):
            n = grupos[x[1]]
            txt.append(f"{x[1]} (entregas {', '.join(n)})" if len(n) > 1 else f"{x[1]} (entrega {n[0]})")
        else:
            txt.append(x)
    return "; ".join(txt)


def criterios_auto(cols, filas):
    """Para indicadores sin regla: columnas numerador_X con 0/1 (prefiere las que tienen fecha_X)."""
    cand = [c for c in cols if PREF.match(c) and len(c) > 4 and all(not str(f.get(c, "")).strip() or es_si_no(f[c]) for f in filas)]
    firma = lambda t: "".join(sorted(re.sub(r"[^a-z0-9]", "", t.lower())))
    fechas = {firma(c[6:]) for c in cols if c.lower().startswith("fecha_")}
    det = [c for c in cand if firma(PREF.sub("", c)) in fechas]
    return [[c, etiqueta(c)] for c in (det or cand)]


def procesar(ruta, reglas, metas):
    codigo = os.path.basename(ruta)[:-len("_nominal.csv")]
    with open(ruta, encoding="utf-8-sig", newline="") as fh:
        texto = fh.read()
    if not texto.strip():
        return None
    delim = ";" if texto.split("\n", 1)[0].count(";") > texto.split("\n", 1)[0].count(",") else ","
    filas = list(csv.DictReader(texto.splitlines(), delimiter=delim))
    if not filas:
        return None
    cols = [c for c in filas[0].keys() if c not in (COL_PIDE, COL_MOTIVO)]
    for f in filas:                                   # quita ="..." de una corrida anterior
        for c in cols:
            v = f.get(c) or ""
            m = re.fullmatch(r'="(.*)"', v)
            if m: f[c] = m.group(1)

    ind = metas.get(codigo, {})
    R = reglas.get(codigo)
    if R:
        def requeridos(p):
            if not R.get("etapas"):
                return R.get("criterios", [])
            m = re.match(r"\s*(\d+)", str(p.get(R["etapa"], "")))
            k = int(m.group(1)) if m else len(R["etapas"])
            return [x for et in R["etapas"][:k] for x in et]
        pide = R.get("pide") or ind.get("nombre") or codigo
    else:
        auto = criterios_auto(cols, filas)
        requeridos = lambda p: auto
        pide = ("Debe tener: " + juntar([e for _, e in auto])) if auto else (ind.get("nombre") or codigo)
    if ind.get("requisito"):
        pide = ind["requisito"]

    col_cond = next((c for c in cols if c.lower() == "condicion"), None)
    den_cero = lambda p: str(p.get("denominador", "")).strip() == "0"
    cumple = (lambda p: not re.match(r"no", str(p.get(col_cond, "")), re.I)) if col_cond else (lambda p: str(p.get("numerador", "")).strip() == "1")

    def motivo(p):
        if den_cero(p):
            f = None
            for x in (R or {}).get("fuera", []):
                c, v = x[0], (x[2] if len(x) > 2 else None)
                if (es_no(p.get(c)) if v is None else str(p.get(c, "")).strip() == v):
                    f = x; break
            return "No entra al indicador (no es parte del denominador)" + (": " + f[1] if f else "")
        if cumple(p):
            return ""
        for caso in (R or {}).get("motivos", []):
            ok = all((str(p.get(c, "")).strip() != "") if v == "*" else (str(p.get(c, "")).strip() == v)
                     for c, v in caso.get("si", {}).items())
            if ok:
                return re.sub(r"\{(\w+)\}", lambda m: fecha(p.get(m.group(1), "")), caso["texto"])
        falta = [e for c, e in requeridos(p) if c in p and es_no(p[c])]
        return ("Falta: " + juntar(falta)) if falta else "No cumple (revisar fechas o plazos del indicador)"

    grupo = lambda p: 2 if den_cero(p) else (1 if cumple(p) else 0)
    filas.sort(key=grupo)                              # sort estable: respeta el orden original

    doc = [c for c in cols if re.search(r"doc|dni", c, re.I)]
    def celda(v):
        v = "" if v is None else str(v)
        return '"' + v.replace('"', '""') + '"' if re.search(r'[;,"\r\n]', v) else v
    # orden de columnas: las del reporte y, justo después de Condicion, las dos nuevas
    pos = cols.index(col_cond) + 1 if col_cond else len(cols)
    orden = cols[:pos] + [COL_PIDE, COL_MOTIVO] + cols[pos:]
    salida = [";".join(celda(c) for c in orden)]
    n_no = 0
    for p in filas:
        m = motivo(p)
        if m and not m.startswith("No entra"):
            n_no += 1
        extra = {COL_PIDE: pide, COL_MOTIVO: m}
        valores = [celda(extra[c]) if c in extra else (f'="{p[c]}"' if c in doc and p.get(c) else celda(p.get(c))) for c in orden]
        salida.append(";".join(valores))
    with open(ruta, "w", encoding="utf-8-sig", newline="") as fh:
        fh.write("\r\n".join(salida))
    return codigo, len(filas), n_no, sum(1 for p in filas if den_cero(p))


def main():
    with open(os.path.join(RAIZ, "reglas_nominal.json"), encoding="utf-8") as fh:
        reglas = {k: v for k, v in json.load(fh).items() if not k.startswith("_")}
    metas = {}
    try:
        with open(os.path.join(RAIZ, "datos", "indicadores_meta.json"), encoding="utf-8-sig") as fh:
            m = json.load(fh)
        for x in (m if isinstance(m, list) else [m]):
            metas[x.get("codigo")] = x
    except Exception:
        pass
    for ruta in sorted(glob.glob(os.path.join(RAIZ, "privado", "*_nominal.csv"))):
        try:
            r = procesar(ruta, reglas, metas)
            if r:
                print(f"{r[0]:<9} motivos ok: {r[2]:>6} no cumplen" + (f", {r[3]} no aplica" if r[3] else ""))
        except Exception as e:
            print(f"{os.path.basename(ruta)}  ERROR: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()

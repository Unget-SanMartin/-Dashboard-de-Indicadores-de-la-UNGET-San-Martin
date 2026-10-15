/* Funciones compartidas por index.html y detalle.html */
const ESTADOS = {
  cumple:   {txt:"Cumple",     color:"var(--ok)"},
  proceso:  {txt:"En proceso", color:"var(--mid)"},
  nocumple: {txt:"No cumple",  color:"var(--bad)"},
  sinmeta:  {txt:"Sin meta",   color:"var(--none)"},
  sindatos: {txt:"Sin datos",  color:"var(--none)"}
};
const TODOS = "__todos", SIN_MR = "Sin MicroRed";
let CFG = {}, IND = new Map(), DATOS = [];

function parseCSV(texto, mantenerMayus = false){
  texto = texto.replace(/^\uFEFF/, "");
  const filas = []; let fila = [], campo = "", q = false;
  for (let i = 0; i < texto.length; i++){
    const c = texto[i];
    if (q){
      if (c === '"' && texto[i+1] === '"'){ campo += '"'; i++; }
      else if (c === '"') q = false; else campo += c;
    } else if (c === '"') q = true;
    else if (c === "," || c === ";"){ fila.push(campo); campo = ""; }
    else if (c === "\n" || c === "\r"){
      if (c === "\r" && texto[i+1] === "\n") i++;
      fila.push(campo); campo = "";
      if (fila.some(v => v.trim())) filas.push(fila);
      fila = [];
    } else campo += c;
  }
  fila.push(campo); if (fila.some(v => v.trim())) filas.push(fila);
  const cab = filas.shift().map(h => mantenerMayus ? h.trim() : h.trim().toLowerCase());
  return filas.map(f => Object.fromEntries(cab.map((h, i) => [h, (f[i] ?? "").trim()])));
}
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const num = v => { const n = parseFloat(String(v).replace(",", ".")); return isNaN(n) ? 0 : n; };
const fN = v => v.toLocaleString("es-PE", {maximumFractionDigits:0});
const fP = v => v == null ? "—" : v.toLocaleString("es-PE", {minimumFractionDigits:1, maximumFractionDigits:1}) + "%";
const MESES = ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"];
const fPer = p => { const m = /^(\d{4})-(\d{2})/.exec(p); return m ? `${MESES[+m[2]-1]} ${m[1]}` : p; };
// DIM_FED_Indicador guarda las metas como fracción (0.434 = 43.4%)
const aPct = v => (v == null || v === "") ? null : (+v <= 1 ? +v * 100 : +v);
const esDesc = ind => /desc|neg|menor|invers|reduc/i.test(ind.sentido || "");

function estado(avance, ind){
  if (avance == null) return "sindatos";
  if (ind.meta == null) return "sinmeta";
  const f = CFG.factor_en_proceso ?? 0.8;
  if (esDesc(ind)){
    if (avance <= ind.meta) return "cumple";
    return avance <= (ind.umbral ?? ind.meta / f) ? "proceso" : "nocumple";
  }
  if (avance >= ind.meta) return "cumple";
  return avance >= (ind.umbral ?? ind.meta * f) ? "proceso" : "nocumple";
}
const pill = e => `<span class="pill" style="background:${ESTADOS[e].color}">${ESTADOS[e].txt}</span>`;
const indDe = c => IND.get(c) || {codigo:c, nombre:c, meta:null, umbral:null, sentido:"", grano:""};
// Sin denominador (0 de 0) cuenta como 0%
const avance = r => r.d > 0 ? r.n / r.d * 100 : 0;
// Evita "220901 220901 TARAPOTO" cuando el distrito ya trae el ubigeo
const nomDist = r => !r.ubigeo || String(r.distrito).startsWith(r.ubigeo) ? (r.distrito || r.ubigeo) : `${r.ubigeo} ${r.distrito}`;
function sumar(rows){
  let n = 0, d = 0; for (const r of rows){ n += r.n; d += r.d; }
  return {n, d, av: d > 0 ? n / d * 100 : 0};
}
// Cuántos casos más necesita un registro para llegar a la meta
function faltan(r, ind){
  if (ind.meta == null || !r.d || esDesc(ind)) return null;
  const x = Math.ceil(ind.meta / 100 * r.d - r.n - 1e-9);
  return x > 0 ? x : 0;
}

async function cargarDatos(){
  const [a, b, c] = await Promise.all(["datos/config.json", "datos/indicadores_meta.json", "datos/indicadores.csv"]
    .map(u => fetch(u, {cache:"no-store"})));
  if (!a.ok || !b.ok || !c.ok) throw new Error("Faltan archivos en la carpeta datos/.");
  CFG = await a.json();
  CFG.ultimo_csv = c.headers.get("Last-Modified");   // respaldo para la hora
  const metas = await b.json();
  const crudo = parseCSV(await c.text());
  if (!crudo.length) throw new Error("datos/indicadores.csv está vacío.");
  if (!("distrito" in crudo[0])) throw new Error("datos/indicadores.csv tiene el formato anterior. Vuelve a ejecutar actualizar.ps1.");
  DATOS = crudo.map(r => ({...r, mr: r.microred || SIN_MR, n: num(r.numerador), d: num(r.denominador)}));
  (Array.isArray(metas) ? metas : [metas])
    .sort((x, y) => String(x.eje).localeCompare(String(y.eje)) || String(x.codigo).localeCompare(String(y.codigo), "es", {numeric:true}))
    .forEach(m => IND.set(m.codigo, {codigo:m.codigo, nombre:m.nombre || m.codigo, eje:m.eje,
      grano:m.grano || "", meta:aPct(m.meta), umbral:aPct(m.umbral_en_proceso), sentido:m.sentido || ""}));
  try{
    const m = await fetch("datos/actualizado.json", {cache:"no-store"});
    if (m.ok){ const j = await m.json(); CFG.actualizado = j.actualizado; CFG.fecha_hora = j.fecha_hora; }
  } catch(_){}
  pintarActualizacion();
}

// Recuadro "Última actualización" en el encabezado
function pintarActualizacion(){
  const h = document.querySelector("header .hwrap");
  if (!h) return;
  if (!CFG.actualizado && CFG.ultimo_csv){
    const d = new Date(CFG.ultimo_csv);
    if (!isNaN(d)) CFG.actualizado = d.toLocaleDateString("es-PE", {day:"2-digit", month:"2-digit", year:"numeric"});
  }
  if (!CFG.actualizado) return;
  let hora = "";
  // 1) hora que guarda actualizar.ps1; 2) si no está, la hora en que se generó indicadores.csv
  for (const v of [CFG.fecha_hora, CFG.ultimo_csv]){
    const d = v ? new Date(v) : null;
    if (d && !isNaN(d)){ hora = d.toLocaleTimeString("es-PE", {hour:"numeric", minute:"2-digit", hour12:true}); break; }
  }
  let caja = document.getElementById("ultimaAct");
  if (!caja){ caja = document.createElement("div"); caja.id = "ultimaAct"; caja.className = "ultima"; h.appendChild(caja); }
  caja.innerHTML = `<span class="cal" aria-hidden="true">📅</span>
    <span><small>Última actualización</small><b>${esc(CFG.actualizado)}</b>${hora ? `<small>Actualizado: ${esc(hora)}</small>` : ""}</span>`;
}

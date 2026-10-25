// Funções usadas pela tela do aluno e pelo painel do treinador.
var CFG = window.AV_CONFIG || {};
var sb = null;
if (CFG.SUPABASE_URL && CFG.SUPABASE_KEY && window.supabase) {
  // A tela do aluno não usa login: nada de sessão guardada nem leitura do
  // endereço (o código do aluno também fica depois do #).
  sb = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_KEY, window.AV_ALUNO ? {auth:{persistSession:false, autoRefreshToken:false, detectSessionInUrl:false}} : {});
}
var app = document.getElementById("app");
function $(id){ return document.getElementById(id); }
function esc(t){ return String(t == null ? "" : t).replace(/[&<>"]/g, function(c){ return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]; }); }
function toast(m){ var t = $("toast"); t.textContent = m; t.hidden = false; clearTimeout(toast.h); toast.h = setTimeout(function(){ t.hidden = true; }, 4200); }
function topBar(sub, title){ return '<header class="top"><div class="in"><img class="logo" src="logo.png" alt="AV Team" width="66" height="63"><div><p class="hello">' + sub + '</p><h1>' + title + '</h1></div></div></header>'; }
function num(v){ var n = parseFloat(String(v == null ? "" : v).replace(",", ".")); return isFinite(n) ? n : null; }
function tonSeries(list){ var t = 0; list.forEach(function(x){ var k = num(x.carga), r = parseInt(x.repeticoes, 10); if (k > 0 && r > 0) t += k * r; }); return t; }
function kg(v){ return Number(v).toLocaleString("pt-BR", {maximumFractionDigits:2}); }
function fmtS(t){ return t.toLocaleString("pt-BR", {maximumFractionDigits:0}) + " kg"; }
function fmt(t){ return fmtS(t) + " (" + (t / 1000).toLocaleString("pt-BR", {maximumFractionDigits:2}) + " t)"; }
function dataCurta(d){ return new Date(d).toLocaleDateString("pt-BR", {day:"2-digit", month:"2-digit", year:"2-digit"}); }
function dataLonga(d){ return new Date(d).toLocaleDateString("pt-BR", {weekday:"short", day:"2-digit", month:"short"}); }
function haQuanto(d){
  var dias = Math.floor((new Date().setHours(0,0,0,0) - new Date(d).setHours(0,0,0,0)) / 864e5);
  return dias <= 0 ? "hoje" : dias === 1 ? "ontem" : "há " + dias + " dias";
}
function guarda(k, v){ try { if (v == null) localStorage.removeItem(k); else localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
function pega(k){ try { var r = localStorage.getItem(k); return r ? JSON.parse(r) : null; } catch (e) { return null; } }
function novoId(){
  if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
  var b = crypto.getRandomValues(new Uint8Array(16)); b[6] = b[6] & 15 | 64; b[8] = b[8] & 63 | 128;
  var h = Array.prototype.map.call(b, function(x){ return (x + 256).toString(16).slice(1); }).join("");
  return h.slice(0, 8) + "-" + h.slice(8, 12) + "-" + h.slice(12, 16) + "-" + h.slice(16, 20) + "-" + h.slice(20);
}
function copiar(txt, campo, ok){
  if (campo) { campo.value = txt; campo.select(); }
  try { navigator.clipboard.writeText(txt).then(function(){ toast(ok); }, function(){ toast("Copie o texto no campo."); }); }
  catch (e) { toast("Copie o texto no campo."); }
}
// Chama uma função do banco. Devolve o resultado ou lança o erro.
async function rpc(nome, args){
  var r = await sb.rpc(nome, args || {});
  if (r.error) throw r.error;
  return r.data;
}
function semConfig(){
  app.innerHTML = topBar("AV Team", "Treinos") + '<main><div class="aviso"><p>O app ainda não foi ligado ao banco de dados.</p><p>Preencha o arquivo <strong>config.js</strong> seguindo o LEIA-ME.</p></div></main>';
}

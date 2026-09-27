// Menú ≡ común a las páginas de Peripatéticos (solo existe en la plantilla:
// init-plantilla.yml lo borra en los proyectos hijos).
// Uso: <script src="menu.js"></script> en el <head>. Pone el botón en la barra
// .top de la página, y da estilo a los recuadros .pm-intro («Qué hace esta
// página»): un <details> plegado que cada página lleva al principio.
(function(){
  var INST = 'peripateticos-v1', BAJA = 'peripateticos-baja-v1', NOMBRE = 'peripateticos-nombre-v1';
  var ORDEN = ['nombre','github','org','fly','claude','drive','pc','verdrive'];

  var css = ''
    + '.pm-btn{flex:none;display:inline-flex;align-items:center;gap:.4rem;height:2.3rem;padding:0 .75rem;border:1px solid var(--line,#DED7C9);border-radius:8px;background:var(--bg2,#fff);color:var(--ink,#1E2528);font:600 .88rem var(--sans,system-ui,sans-serif);cursor:pointer}'
    + '.pm-btn svg{width:1.15rem;height:1.15rem;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round}'
    + '.pm-btn:focus-visible,.pm-panel a:focus-visible,.pm-panel button:focus-visible{outline:2px solid var(--acc,#9A4A2C);outline-offset:2px}'
    + '@media (max-width:340px){.pm-btn .pm-txt{display:none}.pm-btn{padding:0 .55rem}}'
    + '.pm-fondo{position:fixed;inset:0;z-index:90;background:rgba(15,18,20,.5);opacity:0;visibility:hidden;transition:opacity .2s,visibility .2s}'
    + '.pm-panel{position:fixed;left:0;right:0;top:0;z-index:91;max-height:100vh;max-height:100dvh;overflow-y:auto;overscroll-behavior:contain;background:var(--bg,#F6F2EA);color:var(--ink,#1E2528);border-bottom:1px solid var(--line,#DED7C9);box-shadow:0 14px 34px -12px rgba(0,0,0,.4);transform:translateY(-102%);visibility:hidden;transition:transform .25s ease-out,visibility .25s;font:16px/1.5 var(--sans,system-ui,sans-serif)}'
    + 'html.pm-abierto{overflow:hidden}'
    + '.pm-abierto .pm-fondo{opacity:1;visibility:visible}'
    + '.pm-abierto .pm-panel{transform:none;visibility:visible}'
    + '@media (prefers-reduced-motion:reduce){.pm-panel,.pm-fondo{transition:none}}'
    + '.pm-in{max-width:34rem;margin:0 auto;padding:0 16px 1.4rem}'
    + '.pm-cab{position:sticky;top:0;z-index:1;display:flex;align-items:center;gap:.6rem;padding:.55rem 0;background:var(--bg,#F6F2EA);border-bottom:1px solid var(--line,#DED7C9)}'
    + '.pm-cab b{flex:1;font:700 1.15rem var(--serif,Georgia,serif)}'
    + '.pm-ayuda{margin:.8rem 0 0;font-size:.9rem;color:var(--ink2,#4E585C)}'
    + '.pm-grupo{margin:1.1rem 0 .3rem;font:600 .72rem var(--sans,system-ui,sans-serif);letter-spacing:.09em;text-transform:uppercase;color:var(--mute,#7C868A)}'
    + '.pm-lista{list-style:none;margin:0;padding:0}'
    + '.pm-lista a{display:block;padding:.5rem .7rem;border-radius:10px;color:var(--ink,#1E2528);text-decoration:none}'
    + '.pm-lista a:hover{background:var(--acc2,#9A4A2C14)}'
    + '.pm-lista a[aria-current]{background:var(--acc2,#9A4A2C14);box-shadow:inset 3px 0 0 var(--acc,#9A4A2C)}'
    + '.pm-lista b{display:block;font-weight:600;line-height:1.3}'
    + '.pm-lista span{display:block;margin-top:.1rem;font-size:.86rem;line-height:1.35;color:var(--ink2,#4E585C)}'
    + '.pm-lista .pm-peligro b{color:var(--err,#B3261E)}'
    + '.pm-cero{margin-top:1.3rem;padding:.9rem 1rem;border:1px solid var(--line,#DED7C9);border-radius:14px;background:var(--bg2,#fff)}'
    + '.pm-cero h3{margin:0 0 .3rem;font:700 1.05rem var(--serif,Georgia,serif)}'
    + '.pm-cero p{margin:.4rem 0;font-size:.92rem;color:var(--ink2,#4E585C)}'
    + '.pm-cero .pm-acc{display:flex;flex-wrap:wrap;gap:.5rem;margin:.7rem 0 .2rem}'
    + '.pm-b{display:inline-flex;align-items:center;justify-content:center;min-height:2.5rem;padding:.45rem .9rem;border-radius:10px;border:1px solid var(--line,#DED7C9);background:var(--bg2,#fff);color:var(--ink,#1E2528);font:600 .92rem var(--sans,system-ui,sans-serif);text-decoration:none;cursor:pointer}'
    + '.pm-b.pm-pri{background:var(--acc,#9A4A2C);border-color:var(--acc,#9A4A2C);color:var(--acc-ink,#fff)}'
    + '.pm-borrar{margin-top:.9rem;padding-top:.8rem;border-top:1px dashed var(--line,#DED7C9)}'
    + '.pm-borrar button{padding:0;border:0;background:none;text-align:left;color:var(--err,#B3261E);font:600 .9rem var(--sans,system-ui,sans-serif);text-decoration:underline;text-underline-offset:2px;cursor:pointer}'
    // Recuadro «Qué hace esta página», al principio de cada página.
    // Es un <details> plegado: se despliega al tocar el título.
    + '.pm-intro{margin:1.2rem 0 1rem;border:1px solid var(--line,#DED7C9);border-left:4px solid var(--acc,#9A4A2C);border-radius:12px;background:var(--bg2,#fff);color:var(--ink,#1E2528)}'
    + '.pm-intro>summary{display:flex;align-items:center;gap:.6rem;min-height:2.9rem;padding:.55rem .8rem .55rem 1rem;cursor:pointer;list-style:none;font:600 .74rem var(--sans,system-ui,sans-serif);letter-spacing:.09em;text-transform:uppercase;color:var(--acc,#9A4A2C);-webkit-tap-highlight-color:transparent}'
    + '.pm-intro>summary::-webkit-details-marker{display:none}'
    + '.pm-flecha{flex:none;margin-left:auto;display:grid;place-items:center;width:1.9rem;height:1.9rem;border-radius:50%;background:var(--acc2,#9A4A2C14)}'
    + '.pm-flecha svg{width:1.15rem;height:1.15rem;fill:none;stroke:currentColor;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round;transition:transform .2s}'
    + '.pm-intro[open] .pm-flecha svg{transform:rotate(180deg)}'
    + '.pm-intro>summary:focus-visible{outline:2px solid var(--acc,#9A4A2C);outline-offset:2px;border-radius:10px}'
    + '@media (prefers-reduced-motion:reduce){.pm-flecha svg{transition:none}}'
    + '.pm-intro dl{margin:0;padding:0 1rem .9rem;display:grid;gap:.5rem}'
    + '.pm-intro dt{font-weight:600;font-size:.93rem;line-height:1.3}'
    + '.pm-intro dd{margin:.1rem 0 0;font-size:.95rem;line-height:1.45;color:var(--ink2,#4E585C)}'
    // Aviso de app a medias, encima del recuadro.
    + '.pm-aviso{margin:1rem 0 0;padding:.8rem 1rem;border:2px solid var(--acc,#9A4A2C);border-radius:12px;background:var(--bg2,#fff);color:var(--ink,#1E2528);font-size:.95rem}'
    + '.pm-aviso button{padding:0;border:0;background:none;color:var(--acc,#9A4A2C);font:600 .9rem var(--sans,system-ui,sans-serif);text-decoration:underline;text-underline-offset:2px;cursor:pointer}'
    // Barras flotantes (la de arriba de cada página y la cabecera del menú ≡): al
    // pasar el contenido por debajo se estrechan, se vuelven algo transparentes y
    // proyectan sombra, oscura de día y clara de noche.
    + ':root{--pm-sombra:rgba(20,24,26,.32)}'
    + '@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--pm-sombra:rgba(255,255,255,.3)}}'
    + ':root[data-theme="dark"]{--pm-sombra:rgba(255,255,255,.3)}'
    + '.pm-flota{position:sticky;top:0;z-index:20;background-color:var(--bg,#F6F2EA);transition:background-color .2s,box-shadow .2s,border-color .2s}'
    + '.pm-fila{transition:padding .2s}'
    + '.pm-flota .ibtn,.pm-flota .pm-btn{transition:height .2s,width .2s}'
    + ':root .pm-flota.pm-scroll{background-color:color-mix(in srgb,var(--bg,#F6F2EA) 80%,transparent);-webkit-backdrop-filter:blur(10px) saturate(1.2);backdrop-filter:blur(10px) saturate(1.2);box-shadow:0 10px 22px -10px var(--pm-sombra);border-bottom-color:transparent}'
    + ':root .pm-scroll .pm-fila,:root .pm-fila.pm-scroll{padding-top:.28rem;padding-bottom:.28rem}'
    + ':root .pm-scroll .ibtn{width:2.05rem;height:2.05rem}'
    + ':root .pm-scroll .pm-btn{height:2.05rem}'
    + '@media (prefers-reduced-motion:reduce){.pm-flota,.pm-fila,.pm-flota .ibtn,.pm-flota .pm-btn{transition:none}}';
  var s = document.createElement('style'); s.textContent = css; document.head.appendChild(s);

  function lee(k){ try { return JSON.parse(localStorage.getItem(k) || '{}') || {} } catch(e){ return {} } }
  function esc(t){ return String(t==null?'':t).replace(/[&<>"]/g,function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c] }) }

  // Dónde va el montaje guardado en este navegador.
  function montaje(){
    var st = lee(INST), h = st.hechos || {}, i = 0;
    while (i < ORDEN.length && h[ORDEN[i]]) i++;
    return { app: String((st.datos && st.datos.nombre) || '').trim(), paso: i + 1, total: ORDEN.length,
      aMedias: i > 0 && i < ORDEN.length && !!h.nombre, terminado: i >= ORDEN.length };
  }

  // Deja la app a medias y empieza otra: lo hace instalar.html al recibir ?nueva=1
  // (conserva las cuentas ya comprobadas).
  function empezarOtra(){
    var m = montaje(), a = m.app ? '«' + m.app + '»' : 'la app que tienes a medias';
    if (m.aMedias && !confirm('¿Dejar ' + a + ' y empezar otra app?\n\n'
      + 'Lo que escribiste para ' + a + ' se borra de este navegador. Tus cuentas de GitHub, Fly.io y Claude se quedan guardadas.\n\n'
      + 'Si el PC ya llegó a crearla, sigue existiendo en internet: para quitarla del todo, usa «Eliminar una app».')) return;
    location.href = 'instalar.html?nueva=1#instalar';
  }

  // Olvida todo lo que Peripatéticos guarda en este navegador (menos el tema).
  function borrarTodo(){
    if (!confirm('¿Borrar todo lo que Peripatéticos recuerda en este navegador?\n\n'
      + 'Se olvidan tus cuentas, la lista de tus apps y cualquier instalación, cambio de nombre o eliminación que esté a medias.\n\n'
      + 'Tus apps NO se borran: siguen en GitHub, Fly.io y Google Drive.')) return;
    var tema = lee(INST).tema;
    try {
      [BAJA, NOMBRE].forEach(function(k){ localStorage.removeItem(k) });
      if (tema) localStorage.setItem(INST, JSON.stringify({ tema: tema })); else localStorage.removeItem(INST);
    } catch(e){}
    location.href = './';
  }

  window.peripateticos = { montaje: montaje, empezarOtra: empezarOtra, borrarTodo: borrarTodo };

  function items(m){
    var inst = m.aMedias
      ? { href: 'instalar.html#instalar', t: 'Seguir instalando' + (m.app ? ' «' + m.app + '»' : ''), d: 'Vas por el paso ' + m.paso + ' de ' + m.total + '. Sigues donde lo dejaste.' }
      : { href: 'instalar.html#instalar', t: 'Instalar una app', d: 'Crea tu app en 8 pasos guiados. La primera vez, unos 30 minutos.' };
    return [
      { g: 'Empieza aquí' },
      { href: './', t: 'Inicio', d: 'La página principal, con todas las opciones.' },
      { href: 'instalar.html#portada', t: 'Qué es Peripatéticos', d: 'Qué consigues, qué necesitas y cuánto cuesta. Solo para leer.' },
      inst,
      { href: 'pc.html', t: 'En el PC', d: 'La página que se abre en el ordenador para descargar el archivo que monta tu app.' },
      { g: 'Con tu app ya hecha' },
      { href: 'instalar.html#ficha', t: 'Ficha de tu app', d: 'Sus direcciones y un botón para comprobar que responde.' },
      { href: 'instalar.html#pedir', t: 'Pedirle cambios', d: 'Te ayuda a escribir el encargo para Claude.' },
      { href: 'renombrar.html', t: 'Cambiar el nombre', d: 'Ponerle otro nombre a una app que ya tienes.' },
      { href: 'desinstalar.html', t: 'Eliminar una app', d: 'Borrarla de internet para siempre. No se puede deshacer.', peligro: true },
      { g: 'Ayuda' },
      { href: 'instalar.html#ayuda', t: 'Si algo se atasca', d: 'Soluciones a los problemas más habituales.' },
      { href: 'recorrido.html', t: 'El recorrido', d: 'Todas las pantallas que vas a ver al instalar, para saber qué esperar.' }
    ];
  }

  // La opción de la página en la que estás.
  function actual(href){
    var f = location.pathname.split('/').pop() || 'index.html', p = href.split('#');
    if ((p[0] === './' ? 'index.html' : p[0]) !== f) return false;
    if (f !== 'instalar.html') return !p[1];
    var h = location.hash.slice(1);
    return p[1] === (['instalar','ficha','pedir','ayuda'].indexOf(h) < 0 ? 'portada' : h);
  }

  function pinta(panel){
    var m = montaje(), html = '';
    var lista = items(m), abierta = false;
    lista.forEach(function(x){
      if (x.g) { html += (abierta ? '</ul>' : '') + '<p class="pm-grupo">' + esc(x.g) + '</p><ul class="pm-lista">'; abierta = true; return }
      html += '<li><a href="' + esc(x.href) + '"' + (x.peligro ? ' class="pm-peligro"' : '') + (actual(x.href) ? ' aria-current="page"' : '') + '><b>' + esc(x.t) + '</b><span>' + esc(x.d) + '</span></a></li>';
    });
    html += '</ul>';

    html += '<section class="pm-cero" aria-labelledby="pm-cero-t"><h3 id="pm-cero-t">Empezar de cero</h3>';
    if (m.aMedias) {
      html += '<p>Tienes a medias <b>' + esc(m.app ? '«' + m.app + '»' : 'una app') + '</b>: vas por el paso ' + m.paso + ' de ' + m.total + '.</p>'
        + '<div class="pm-acc"><a class="pm-b" href="instalar.html#instalar">Seguir con ella</a><button class="pm-b pm-pri" type="button" data-pm="otra">Dejarla y empezar otra</button></div>'
        + '<p>Al empezar otra, tus cuentas se quedan guardadas: no tendrás que volver a crearlas.</p>';
    } else {
      html += '<p>' + (m.terminado ? 'Tu última app está terminada.' : 'No tienes ninguna instalación a medias.') + ' Para crear otra, empieza aquí: tus cuentas se quedan guardadas.</p>'
        + '<div class="pm-acc"><button class="pm-b pm-pri" type="button" data-pm="otra">Montar una app nueva</button></div>';
    }
    html += '<div class="pm-borrar"><button type="button" data-pm="todo">Borrar todo lo guardado en este navegador</button>'
      + '<p>Olvida tus cuentas y la lista de tus apps en este móvil u ordenador. Tus apps no se tocan.</p></div></section>';
    panel.querySelector('.pm-cuerpo').innerHTML = html;
  }

  // Marca una barra flotante mientras hay contenido pasando por debajo.
  function flota(barra, fila, desliza){
    barra.classList.add('pm-flota'); fila.classList.add('pm-fila');
    var pendiente = false;
    function mira(){ pendiente = false; barra.classList.toggle('pm-scroll', (desliza === window ? window.scrollY : desliza.scrollTop) > 4) }
    desliza.addEventListener('scroll', function(){ if (!pendiente) { pendiente = true; requestAnimationFrame(mira) } }, { passive: true });
    mira();
    return mira;
  }

  function monta(){
    var barra = document.querySelector('.top .in') || document.querySelector('.top .fila') || document.querySelector('.top');
    if (!barra || document.getElementById('pm-btn')) return;
    flota(document.querySelector('.top'), barra, window);

    var btn = document.createElement('button');
    btn.type = 'button'; btn.id = 'pm-btn'; btn.className = 'pm-btn';
    btn.setAttribute('aria-expanded', 'false'); btn.setAttribute('aria-controls', 'pm-panel'); btn.setAttribute('aria-label', 'Abrir el menú');
    btn.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg><span class="pm-txt">Menú</span>';
    barra.appendChild(btn);

    var fondo = document.createElement('div'); fondo.className = 'pm-fondo';
    var panel = document.createElement('nav');
    panel.id = 'pm-panel'; panel.className = 'pm-panel'; panel.setAttribute('aria-label', 'Menú de Peripatéticos');
    panel.innerHTML = '<div class="pm-in"><div class="pm-cab"><b>Menú</b>'
      + '<button class="pm-btn" type="button" data-pm="cerrar" aria-label="Cerrar el menú"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg><span class="pm-txt">Cerrar</span></button></div>'
      + '<p class="pm-ayuda">Toca una opción para ir a ella. Al principio de cada página, «Qué hace esta página» se despliega con un toque y lo explica.</p>'
      + '<div class="pm-cuerpo"></div></div>';
    document.body.appendChild(fondo); document.body.appendChild(panel);
    var cab = panel.querySelector('.pm-cab'), miraCab = flota(cab, cab, panel);

    var raiz = document.documentElement;
    function abre(){ pinta(panel); panel.scrollTop = 0; miraCab(); raiz.classList.add('pm-abierto'); btn.setAttribute('aria-expanded', 'true'); panel.querySelector('[data-pm="cerrar"]').focus() }
    function cierra(foco){ if (!raiz.classList.contains('pm-abierto')) return; raiz.classList.remove('pm-abierto'); btn.setAttribute('aria-expanded', 'false'); if (foco) btn.focus() }
    btn.addEventListener('click', function(){ raiz.classList.contains('pm-abierto') ? cierra(true) : abre() });
    fondo.addEventListener('click', function(){ cierra(true) });
    document.addEventListener('keydown', function(e){ if (e.key === 'Escape') cierra(true) });
    panel.addEventListener('click', function(e){
      var b = e.target.closest('[data-pm]'), a = e.target.closest('a');
      if (b && b.dataset.pm === 'cerrar') cierra(true);
      else if (b && b.dataset.pm === 'otra') empezarOtra();
      else if (b && b.dataset.pm === 'todo') borrarTodo();
      else if (a) cierra(false);   // los enlaces a otra pantalla de la misma página no recargan
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', monta); else monta();
})();

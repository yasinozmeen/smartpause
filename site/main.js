/* SmartPause site — scroll-driven story.
   One idea: the key's pulse travels down the page. Every chapter is scrubbed by scroll, nothing autoplays. */
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const copyBtn = document.querySelector('[data-copy]');
  copyBtn?.addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(document.getElementById('cmd').textContent.trim()); copyBtn.textContent = 'Copied'; }
    catch { copyBtn.textContent = 'Select and copy'; }
    setTimeout(() => (copyBtn.textContent = 'Copy'), 1600);
  });
  if (reduce || !window.gsap) return;

  gsap.registerPlugin(ScrollTrigger);

  // Smooth scroll (Lenis) feeding GSAP's ticker. (?y=<px>: doğrulama modu, düz kaydırma.)
  const debugY = parseFloat(new URLSearchParams(location.search).get('y'));
  let lenis = null;
  if (isNaN(debugY)) {
    lenis = new Lenis({ lerp: 0.09, smoothWheel: true });
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add((t) => lenis.raf(t * 1000));
    gsap.ticker.lagSmoothing(0);
  }

  const ease = 'power2.inOut';

  // Rail: fills with page progress; the pulse rides its tip.
  gsap.to('.rail-fill', { height: '100%', ease: 'none', scrollTrigger: { trigger: 'main', start: 'top top', end: 'bottom bottom', scrub: 0.4 } });
  gsap.to('.pulse', { top: '100%', ease: 'none', scrollTrigger: { trigger: 'main', start: 'top top', end: 'bottom bottom', scrub: 0.4 } });
  gsap.to('.pulse', { opacity: 1, scrollTrigger: { trigger: '#hero', start: '40% top', end: '70% top', scrub: true } });

  // 1 · Hero: scroll presses the key. Headline stays until the press lands, then dissolves.
  gsap.timeline({ scrollTrigger: { trigger: '#hero', start: 'top top', end: '+=110%', scrub: 0.6, pin: true } })
    .to('.key', { scale: 0.94, y: 18, boxShadow: '0 12px 40px rgba(0,0,0,.7), inset 0 2px 0 rgba(255,255,255,.06), inset 0 0 0 1.5px rgba(107,156,255,.45)', duration: 0.45, ease })
    .to('.key-shadow', { opacity: 1, duration: 0.3 }, '<0.15')
    .to('.scroll-hint', { opacity: 0, duration: 0.2 }, '<')
    .to('.key', { scale: 1, y: 0, duration: 0.35, ease: 'power3.out' })
    .to('.key-shadow', { opacity: 0, scale: 2.2, duration: 0.6 }, '<')
    .to(['.h-display .l1', '.h-display .l2', '.lede'], { opacity: 0, y: -30, stagger: 0.06, duration: 0.5, ease }, '<0.1')
    .to('.key', { y: '30vh', scale: 0.7, opacity: 0, duration: 0.8, ease: 'power2.in' }, '<0.2');

  // Shared chapter choreography: text rises in, tiles settle, then the scene plays.
  function chapter(id, play) {
    const tl = gsap.timeline({ scrollTrigger: { trigger: id, start: 'top top', end: '+=150%', scrub: 0.6, pin: true } });
    // Metin ve kartlar sabitlenir sabitlenmez görünür (boş ekran yok); yalnız hafif bir yerleşme.
    tl.from(`${id} .tile, ${id} .widget`, { y: 18, stagger: 0.06, duration: 0.3, ease });
    play(tl, id);
    tl.to({}, { duration: 0.4 });   // rest at the end of the chapter
    return tl;
  }

  // 2 · Today: pulse hits Apple Music; it springs open, YouTube keeps playing.
  chapter('#today', (tl, id) => {
    const wrong = `${id} .tile.wrong`;
    tl.fromTo(`${id} .tile.wrong`, { x: 0 }, { x: 0, duration: 0.2 })
      .to(wrong, { borderColor: 'rgba(255,69,58,.7)', backgroundColor: '#2a1418', scale: 1.04, x: 12, duration: 0.35, ease: 'back.out(2)' })
      .to(`${wrong} .state`, { color: '#FF6B61', duration: 0.2 }, '<')
      .to(`${id} [data-app="youtube"] .wave i`, { scaleY: 1.6, stagger: { each: 0.05, yoyo: true, repeat: 3 }, duration: 0.12 }, '<');
  });

  // 3 · With SmartPause: pulse hits YouTube; wave flattens (paused), Music stays shut.
  chapter('#with', (tl, id) => {
    const hit = `${id} .tile.hit`;
    tl.to(hit, { borderColor: 'rgba(107,156,255,.8)', backgroundColor: '#15203a', x: 12, duration: 0.35, ease: 'back.out(2)' })
      .to(`${hit} .wave i`, { scaleY: 0.18, stagger: 0.04, duration: 0.3, ease: 'power3.out' }, '<0.1')
      .to(`${id} .tile.shut`, { opacity: 0.45, duration: 0.3 }, '<');
  });

  // 4 · Two sources: scroll performs the swap, then the double press.
  chapter('#two', (tl, id) => {
    const rowA = `${id} [data-row="a"]`, rowB = `${id} [data-row="b"]`;
    const setText = (sel, txt) => () => { document.querySelector(sel).innerHTML = txt; };
    tl.to(`${id} [data-press]`, { opacity: 1, duration: 0.15 })
      // single press: Spotify pauses, Brave rises to the top (depth), hint flips
      .to(rowA, { y: 48, scale: 0.94, opacity: 0.55, filter: 'blur(1.2px)', duration: 0.45, ease })
      .to(rowB, { y: -48, scale: 1.06, boxShadow: '0 14px 26px rgba(0,0,0,.6)', duration: 0.45, ease }, '<')
      .to(rowB, { scale: 1, boxShadow: '0 0 0 rgba(0,0,0,0)', duration: 0.25 })
      .to(rowA, { scale: 1, opacity: 1, filter: 'blur(0px)', duration: 0.25 }, '<')
      .call(setText(`${id} [data-a]`, 'Paused'), null, '<')
      .call(setText(`${id} [data-hint]`, 'Single press: switch to Spotify<br>Double press: play/pause Brave'), null, '<')
      .to(`${id} [data-press]`, { opacity: 0, duration: 0.15 })
      .to({}, { duration: 0.3 })
      // double press: Brave pauses
      .call(() => { const l = document.querySelector(`${id} [data-press]`); l.textContent = 'press · press'; })
      .to(`${id} [data-press]`, { opacity: 1, duration: 0.15 })
      .call(setText(`${id} [data-b]`, 'Paused'), null, '+=0.2')
      .to(`${rowB} .g`, { scale: 0.7, duration: 0.15 })
      .call(() => { document.querySelector(`${rowB} .g`).className = 'g g-pause'; })
      .to(`${rowB} .g`, { scale: 1, duration: 0.15 })
      .to(`${id} [data-press]`, { opacity: 0, duration: 0.15 });
  });

  // 5/6 · quiet reveals, once.
  gsap.from('.facts li', { opacity: 0, x: -14, stagger: 0.1, duration: 0.6, ease, scrollTrigger: { trigger: '.facts', start: 'top 70%' } });
  gsap.from('.cmd', { opacity: 0, y: 16, duration: 0.6, ease, scrollTrigger: { trigger: '#install', start: 'top 70%' } });

  addEventListener('load', () => {
    ScrollTrigger.refresh();
    // Görsel doğrulama kancası: ?y=<px> ile belirli bir kaydırma konumuna atla (ekran görüntüsü testleri).
    if (!isNaN(debugY)) { window.scrollTo(0, debugY); ScrollTrigger.update(); requestAnimationFrame(() => ScrollTrigger.update()); }
  });
})();

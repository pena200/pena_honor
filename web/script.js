(() => {
    const $ = (id) => document.getElementById(id);
    const barAnchor = $('barAnchor'), notifyAnchor = $('notifyAnchor');
    const barWrap = $('barWrap'), head = $('head');
    const brightGood = $('brightGood'), brightBad = $('brightBad'), marker = $('marker');

    const NOTE_SVG = '<svg viewBox="0 0 64 64" aria-hidden="true">' +
        '<path class="glyph glyph-good" d="M32 13 37.6 25.6 51.3 27.1 41.1 36.4 44 50 32 43.1 20 50 22.9 36.4 12.7 27.1 26.4 25.6Z"/>' +
        '<path class="glyph glyph-bad" d="M36 12 20 35H30L27 52 44 28H34Z"/></svg>';

    let cfg = { min: -1000, max: 1000, showValue: false, notify: { enabled: true, position: 'middle-right', duration: 4000, max: 3 } };
    let timer = null;

    const ratio = (v) => (v >= 0 ? v / cfg.max : v / Math.abs(cfg.min));
    const restart = (el, cls) => { el.classList.remove(cls); void el.offsetWidth; el.classList.add(cls); };
    const place = (el, pos) => { el.className = 'anchor pos-' + pos; };
    const setMood = (m) => { barWrap.dataset.mood = m; };
    const titleEl = $('title');

    function setTitle(t, animate) {
        if (!animate) { titleEl.textContent = t; return; }
        const w0 = head.offsetWidth;
        titleEl.textContent = t;
        head.style.width = 'max-content';
        const w1 = head.offsetWidth;
        if (w0 === w1) { head.style.width = ''; return; }
        head.style.width = w0 + 'px';
        void head.offsetWidth;
        head.style.width = w1 + 'px';
        setTimeout(() => { head.style.width = ''; }, 500);
    }

    function render(v) {
        const f = Math.min(1, Math.abs(ratio(v)));
        brightGood.style.clipPath = `inset(0 ${100 - (v > 0 ? f : 0) * 100}% 0 0)`;
        brightBad.style.clipPath = `inset(0 0 0 ${100 - (v < 0 ? f : 0) * 100}%)`;
        marker.style.left = (v >= 0 ? 50 + f * 50 : 50 - f * 50) + '%';
        $('value').textContent = cfg.showValue ? v : '';
    }

    function countTo(el, target) {
        const start = performance.now(), dur = 750;
        const step = (t) => {
            const p = Math.min(1, (t - start) / dur);
            const v = Math.round(target * (1 - Math.pow(1 - p, 3)));
            el.textContent = (target > 0 ? '+' : '') + v;
            if (p < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    }

    function notify(d) {
        const n = cfg.notify;
        if (!n || !n.enabled || !d.delta) return;

        const el = document.createElement('div');
        el.className = 'note';
        el.dataset.mood = d.delta > 0 ? 'good' : 'bad';
        el.innerHTML = (n.showReason ? '<div class="note-reason"></div>' : '') +
            '<div class="sign"></div><div class="nbadge">' + NOTE_SVG + '</div>';
        if (n.showReason) el.querySelector('.note-reason').textContent = d.reason || '';

        notifyAnchor.appendChild(el);

        const live = notifyAnchor.querySelectorAll('.note:not(.out)');
        for (let i = 0; i < live.length - (n.max || 3); i++) {
            live[i].classList.add('out');
            setTimeout(() => live[i].remove(), 600);
        }
        setTimeout(() => {
            if (!el.isConnected || el.classList.contains('out')) return;
            el.classList.add('out');
            setTimeout(() => el.remove(), 600);
        }, n.duration || 4000);
    }

    function applyConfig(d) {
        cfg = { min: d.min, max: d.max, showValue: d.showValue, notify: d.notify || { enabled: false } };
        place(barAnchor, d.position);

        const parts = (cfg.notify.position || 'top-right').split('-');
        const v = ['top', 'middle', 'bottom'].includes(parts[0]) ? parts[0] : 'top';
        notifyAnchor.className = 'v-' + v + ' h-' + (parts[1] === 'left' ? 'left' : 'right');

        const map = { good: '--good', goodAlt: '--good-alt', bad: '--bad', badAlt: '--bad-alt', neutral: '--neutral' };
        for (const key in map) {
            if (d.colors && d.colors[key]) document.documentElement.style.setProperty(map[key], d.colors[key]);
        }
    }

    function show(d) {
        clearTimeout(timer);
        const moodChanged = d.fromMood && d.fromMood !== d.mood;
        const titleChanged = d.fromTitle && d.fromTitle !== d.title;


        setMood(d.fromMood || d.mood);
        setTitle(d.fromTitle || d.title);
        barWrap.classList.add('no-anim');
        render(d.from);
        void barWrap.offsetWidth;
        barWrap.classList.remove('no-anim', 'hidden', 'ripple');
        restart(barWrap, 'enter');

        notify(d);

        setTimeout(() => {
            render(d.to);
            if (moodChanged) {
                setMood(d.mood);
                restart(barWrap, 'ripple');
            }
            setTitle(d.title, titleChanged);
            if (titleChanged) restart(head, 'swap');
        }, 300);

        timer = setTimeout(() => barWrap.classList.add('hidden'), d.duration || 5000);
    }


    try {
        const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pena_honor';
        fetch(`https://${res}/ready`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }).catch(() => {});
    } catch (e) {}

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'config') applyConfig(d);
        else if (d.action === 'show') show(d);
    });
})();
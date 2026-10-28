// Pointer effects for the home page. Glass cards light up around the cursor,
// [data-tilt] cards lean toward it, and page-wide CSS variables (--px, --py
// from 0 to 1, --cx, --cy in pixels) let backgrounds follow it. Off for touch
// screens and for people who ask for reduced motion.
const fine = matchMedia('(pointer: fine)').matches;
const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

if (fine && !still) {
  const root = document.documentElement;
  const glass = [...document.querySelectorAll('.glass')];
  let x = innerWidth / 2, y = innerHeight / 3, frame = 0, tilted = null;

  const update = () => {
    frame = 0;
    root.style.setProperty('--px', (x / innerWidth).toFixed(3));
    root.style.setProperty('--py', (y / innerHeight).toFixed(3));
    root.style.setProperty('--cx', `${x}px`);
    root.style.setProperty('--cy', `${y}px`);
    for (const el of glass) {
      const r = el.getBoundingClientRect();
      el.style.setProperty('--mx', `${x - r.left}px`);
      el.style.setProperty('--my', `${y - r.top}px`);
    }
    if (tilted) {
      const r = tilted.getBoundingClientRect();
      const dx = (x - r.left) / r.width - 0.5, dy = (y - r.top) / r.height - 0.5;
      const max = Number(tilted.dataset.tilt) || 8;
      tilted.style.setProperty('--ry', `${(dx * max * 2).toFixed(2)}deg`);
      tilted.style.setProperty('--rx', `${(-dy * max * 2).toFixed(2)}deg`);
    }
  };
  const schedule = () => { if (!frame) frame = requestAnimationFrame(update); };

  addEventListener('pointermove', (e) => {
    x = e.clientX; y = e.clientY;
    const over = e.target.closest?.('[data-tilt]') ?? null;
    if (over !== tilted) {
      tilted?.style.setProperty('--rx', '0deg');
      tilted?.style.setProperty('--ry', '0deg');
      tilted = over;
    }
    schedule();
  }, { passive: true });
  addEventListener('scroll', schedule, { passive: true });
  root.classList.add('tracking');
  update();
}

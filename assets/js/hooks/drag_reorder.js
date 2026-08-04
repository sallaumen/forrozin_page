// Reorder a row of chips by holding and dragging.
//
// The held chip lifts into a floating copy that follows the finger and trembles
// lightly; the gap it left slides between the others, so the result is visible
// before letting go. Dropping settles the copy into the gap and stops the tremor.
//
// The host element carries `phx-hook="DragReorder"` and `data-reorder-event`; the
// hook pushes that event with `{order: [id, id, ...]}` once the drop lands.
// Children are marked with `data-reorder-id`. `data-reorder-axis="y"` switches a
// row of chips for a stacked list.
//
// Written as a hook, not inline in one screen, because the sheet in the diary and
// the manual builder on the map need the same gesture over lists that do not even
// run along the same axis.

// Holding beats tapping only after this long: without the delay, scrolling the
// sheet on a phone would rip a chip out on the way past.
const HOLD_MS = 140;
// How far the finger may stray during the hold before it counts as a scroll.
const SLOP_PX = 8;

const DragReorder = {
  mounted() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.vertical = this.el.dataset.reorderAxis === "y";
    this.onPointerDown = (e) => this.maybeStart(e);
    this.el.addEventListener("pointerdown", this.onPointerDown);
    this.el.addEventListener("keydown", (e) => this.onKey(e));
  },

  destroyed() {
    this.el.removeEventListener("pointerdown", this.onPointerDown);
    this.cleanupGhost();
  },

  // ---- gesture ------------------------------------------------------------

  maybeStart(e) {
    if (e.button !== undefined && e.button !== 0) return;
    const item = e.target.closest("[data-reorder-id]");
    if (!item || !this.el.contains(item)) return;
    // A remove button inside the chip is its own gesture, not a handle.
    if (e.target.closest("[data-reorder-ignore]")) return;

    const startX = e.clientX;
    const startY = e.clientY;

    const timer = setTimeout(() => {
      stopWatching();
      this.lift(item, startX, startY);
    }, HOLD_MS);

    const onMove = (ev) => {
      if (Math.hypot(ev.clientX - startX, ev.clientY - startY) > SLOP_PX) {
        clearTimeout(timer);
        stopWatching();
      }
    };
    const onUp = () => {
      clearTimeout(timer);
      stopWatching();
    };
    const stopWatching = () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onUp);
    };

    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onUp);
  },

  lift(item, x, y) {
    const rect = item.getBoundingClientRect();

    const ghost = item.cloneNode(true);
    ghost.removeAttribute("id");
    ghost.dataset.reorderGhost = "true";
    Object.assign(ghost.style, {
      position: "fixed",
      left: `${rect.left}px`,
      top: `${rect.top}px`,
      width: `${rect.width}px`,
      height: `${rect.height}px`,
      margin: "0",
      zIndex: "60",
      pointerEvents: "none"
    });
    ghost.style.setProperty("--drag-x", "0px");
    ghost.style.setProperty("--drag-y", "0px");
    document.body.appendChild(ghost);

    item.dataset.reorderPlaceholder = "true";
    this.el.dataset.reordering = "true";
    // Scroll is blocked only from here: a static touch-action would also eat
    // the scroll of whoever merely rests a finger on an item to pan the list.
    this.onTouchMove = (e) => e.preventDefault();
    window.addEventListener("touchmove", this.onTouchMove, { passive: false });
    if (navigator.vibrate) navigator.vibrate(8);

    this.drag = { item, ghost, grabX: x, grabY: y, origin: rect };

    this.onDragMove = (e) => this.move(e);
    this.onDragUp = () => this.drop();
    window.addEventListener("pointermove", this.onDragMove, { passive: false });
    window.addEventListener("pointerup", this.onDragUp, { once: true });
    window.addEventListener("pointercancel", this.onDragUp, { once: true });
  },

  move(e) {
    if (!this.drag) return;
    e.preventDefault();

    const { ghost, grabX, grabY } = this.drag;
    ghost.style.setProperty("--drag-x", `${e.clientX - grabX}px`);
    ghost.style.setProperty("--drag-y", `${e.clientY - grabY}px`);

    const target = this.slotUnder(e.clientX, e.clientY);
    if (target && target !== this.drag.item) {
      const items = this.items();
      const from = items.indexOf(this.drag.item);
      const to = items.indexOf(target);
      if (from < to) {
        target.after(this.drag.item);
      } else {
        target.before(this.drag.item);
      }
    }
  },

  // The first item the finger has NOT passed yet is the slot it belongs in.
  slotUnder(x, y) {
    const items = this.items();
    for (const item of items) {
      if (!this.passed(item.getBoundingClientRect(), x, y)) return item;
    }
    return items[items.length - 1];
  },

  // A stacked list is one item per line, so the midpoint on Y decides alone.
  // Chips wrap, so comparing X alone would be wrong there: the finger on the
  // second line would match the midpoint of a chip still up on the first. A chip
  // is behind the finger only when its whole line ended above, or when the finger
  // passed its midpoint WITHIN the same line.
  passed(r, x, y) {
    if (this.vertical) return y > r.top + r.height / 2;

    const lineEndedAbove = y > r.bottom;
    const passedInLine = y >= r.top && x > r.left + r.width / 2;
    return lineEndedAbove || passedInLine;
  },

  drop() {
    if (!this.drag) return;
    window.removeEventListener("pointermove", this.onDragMove);

    const { ghost, item, origin } = this.drag;
    const to = item.getBoundingClientRect();
    const dx = to.left - origin.left;
    const dy = to.top - origin.top;

    ghost.dataset.reorderSettling = "true";
    ghost.style.setProperty("--drag-x", `${dx}px`);
    ghost.style.setProperty("--drag-y", `${dy}px`);

    const land = () => {
      this.cleanupGhost();
      item.focus();
    };
    ghost.addEventListener("transitionend", land, { once: true });
    // A settle that never fires a transition (reduced motion, zero distance)
    // must not leave the ghost stuck on top of the page.
    setTimeout(land, 280);

    this.drag = null;
    this.pushOrder();
  },

  cleanupGhost() {
    window.removeEventListener("touchmove", this.onTouchMove);
    document
      .querySelectorAll("[data-reorder-ghost]")
      .forEach((g) => g.remove());
    this.el
      .querySelectorAll("[data-reorder-placeholder]")
      .forEach((p) => delete p.dataset.reorderPlaceholder);
    delete this.el.dataset.reordering;
  },

  // ---- keyboard -----------------------------------------------------------

  // Dragging cannot be the only way in: without this, ordering is out of reach
  // for anyone not using a mouse or a touch screen.
  onKey(e) {
    const back = this.vertical ? "ArrowUp" : "ArrowLeft";
    const forward = this.vertical ? "ArrowDown" : "ArrowRight";
    if (e.key !== back && e.key !== forward) return;

    const item = e.target.closest("[data-reorder-id]");
    if (!item) return;

    const items = this.items();
    const i = items.indexOf(item);
    const j = e.key === back ? i - 1 : i + 1;
    if (j < 0 || j >= items.length) return;

    e.preventDefault();
    if (e.key === back) items[j].before(item);
    else items[j].after(item);
    item.focus();
    this.pushOrder();
  },

  // ---- shared -------------------------------------------------------------

  items() {
    return Array.from(this.el.querySelectorAll("[data-reorder-id]"));
  },

  pushOrder() {
    const event = this.el.dataset.reorderEvent;
    if (!event) return;
    const order = this.items().map((el) => el.dataset.reorderId);
    this.pushEvent(event, { order });
  }
};

export default DragReorder;

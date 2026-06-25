const BottomSheet = {
  mounted() {
    const dialog = this.el;

    this._onOpen = () => {
      if (!dialog.open) dialog.showModal();
    };
    this._onClose = () => {
      if (dialog.open) dialog.close();
    };
    dialog.addEventListener("bottom-sheet:open", this._onOpen);
    dialog.addEventListener("bottom-sheet:close", this._onClose);

    this._onBackdropClick = (e) => {
      const content = dialog.querySelector("[data-bottom-sheet-content]");
      if (content && !content.contains(e.target)) {
        dialog.close();
      }
    };
    dialog.addEventListener("click", this._onBackdropClick);

    const content = dialog.querySelector("[data-bottom-sheet-content]");
    const handle = dialog.querySelector("[data-bottom-sheet-handle]");

    if (handle && content) {
      let startY = null;
      let delta = 0;

      this._onTouchStart = (e) => {
        if (e.touches.length !== 1) return;
        startY = e.touches[0].clientY;
        delta = 0;
        content.style.transition = "none";
      };

      this._onTouchMove = (e) => {
        if (startY === null) return;
        delta = e.touches[0].clientY - startY;
        if (delta > 0) {
          content.style.transform = `translateY(${delta}px)`;
        }
      };

      this._onTouchEnd = () => {
        if (startY === null) return;
        content.style.transition = "transform 200ms var(--ease-out-quart, ease-out)";

        if (delta > 80) {
          content.style.transform = "translateY(100%)";
          setTimeout(() => {
            dialog.close();
            content.style.transform = "";
          }, 200);
        } else {
          content.style.transform = "";
        }

        startY = null;
        delta = 0;
      };

      handle.addEventListener("touchstart", this._onTouchStart, { passive: true });
      handle.addEventListener("touchmove", this._onTouchMove, { passive: true });
      handle.addEventListener("touchend", this._onTouchEnd);
    }
  },

  destroyed() {
    const dialog = this.el;
    dialog.removeEventListener("bottom-sheet:open", this._onOpen);
    dialog.removeEventListener("bottom-sheet:close", this._onClose);
    dialog.removeEventListener("click", this._onBackdropClick);
  },
};

export default BottomSheet

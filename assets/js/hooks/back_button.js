const BackButton = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      if (window.history.length > 1) {
        window.history.back();
      } else {
        const fallback = this.el.dataset.fallback || "/collection";
        window.location.href = fallback;
      }
    });
  }
};

export default BackButton

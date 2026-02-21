const SidebarShell = {
  MOBILE_MEDIA_QUERY: "(max-width: 1023px)",

  mounted() {
    this.sidebar = this.el.querySelector("[data-sidebar]");
    this.overlay = this.el.querySelector("[data-sidebar-overlay]");
    this.openButton = this.el.querySelector("[data-sidebar-open]");

    this.isOpen = false;

    this.matchMedia = window.matchMedia(this.MOBILE_MEDIA_QUERY);

    this.isMobile = () => this.matchMedia.matches;

    this.setOpen = (open) => {
      if (!this.sidebar || !this.overlay) {
        return;
      }

      if (this.isMobile()) {
        this.isOpen = open;
        this.sidebar.classList.toggle("pointer-events-auto", open);
        this.sidebar.classList.toggle("pointer-events-none", !open);
        this.sidebar.classList.toggle("-translate-x-full", !open);
        this.sidebar.classList.toggle("translate-x-0", open);
        this.overlay.classList.toggle("opacity-100", open);
        this.overlay.classList.toggle("pointer-events-auto", open);
        this.overlay.classList.toggle("opacity-0", !open);
        this.overlay.classList.toggle("pointer-events-none", !open);
        document.body.classList.toggle("overflow-hidden", open);
        this.sidebar.setAttribute("aria-hidden", String(!open));
      } else {
        this.isOpen = true;
        this.sidebar.classList.remove("-translate-x-full", "pointer-events-none");
        this.sidebar.classList.add("translate-x-0", "pointer-events-auto");
        this.overlay.classList.remove("opacity-100", "pointer-events-auto");
        this.overlay.classList.add("opacity-0", "pointer-events-none");
        document.body.classList.remove("overflow-hidden");
        this.sidebar.setAttribute("aria-hidden", "false");
      }

      if (this.openButton) {
        this.openButton.setAttribute("aria-expanded", String(this.isOpen));
      }
    };

    this.handleOpenClick = () => {
      if (!this.isMobile()) return;
      this.setOpen(true);
    };

    this.handleCloseClick = (event) => {
      const closeTarget = event.target.closest("[data-sidebar-close]");
      if (closeTarget) {
        this.setOpen(false);
      }
    };

    this.handleEscape = (event) => {
      if (event.key !== "Escape") return;
      if (!this.isMobile() || !this.isOpen) return;
      this.setOpen(false);
    };

    this.handleResize = () => {
      this.setOpen(this.isMobile() ? this.isOpen : true);
    };

    this.el.addEventListener("click", this.handleCloseClick);
    if (this.openButton) {
      this.openButton.addEventListener("click", this.handleOpenClick);
    }
    document.addEventListener("keydown", this.handleEscape);
    this.matchMedia.addEventListener("change", this.handleResize);

    this.setOpen(false);
  },

  reconnected() {
    this.setOpen(this.isMobile() ? this.isOpen : true);
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleCloseClick);
    if (this.openButton) {
      this.openButton.removeEventListener("click", this.handleOpenClick);
    }
    document.removeEventListener("keydown", this.handleEscape);
    this.matchMedia.removeEventListener("change", this.handleResize);
    document.body.classList.remove("overflow-hidden");
  }
};

export default SidebarShell;

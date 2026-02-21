const THEME_KEY = "riak-dashboard-theme";

const normalizeTheme = value => {
  return value === "dark" || value === "light" || value === "auto" ? value : "auto";
};

const systemPrefersDark = () =>
  window.matchMedia("(prefers-color-scheme: dark)").matches;

const isDarkTheme = theme =>
  theme === "dark" || (theme === "auto" && systemPrefersDark());

const applyTheme = (theme) => {
  const html = document.documentElement;
  html.classList.toggle("dark", isDarkTheme(theme));
  window.dispatchEvent(new CustomEvent("riak:theme-changed", {
    detail: {theme}
  }));
};

const updateLogoForTheme = () => {
  const isDark = document.documentElement.classList.contains("dark");
  const lightSrc = "/images/openriak_dashboard_logo.svg";
  const darkSrc = "/images/openriak_dashboard_logo_dark.svg";
  const brightLogoClass = "theme-logo-bright";
  const logos = document.querySelectorAll("[data-theme-image]");

  logos.forEach((logo) => {
    logo.src = isDark ? darkSrc : lightSrc;
    logo.classList.toggle(brightLogoClass, !isDark);
  });
};

const writeTheme = (theme) => {
  try {
    localStorage.setItem(THEME_KEY, theme);
  } catch (_e) {
    // localStorage can be unavailable in restricted privacy modes.
  }
};

const getStoredTheme = () => {
  try {
    return normalizeTheme(localStorage.getItem(THEME_KEY));
  } catch (_e) {
    return "auto";
  }
};

const readButtons = el => {
  return el.querySelectorAll("[data-theme-value]");
};

const setActiveThemeIndicator = (el, theme) => {
  el.setAttribute("data-theme", theme);

  const buttons = readButtons(el);
  buttons.forEach((button) => {
    const value = button.getAttribute("data-theme-value");
    const isActive = value === theme;
    button.classList.toggle("theme-toggle-active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });
};

const ThemeToggle = {
  mounted() {
    this.currentTheme = getStoredTheme();
    this.matchMedia = window.matchMedia("(prefers-color-scheme: dark)");

    this.apply = (theme = this.currentTheme) => {
      this.currentTheme = normalizeTheme(theme);
      applyTheme(this.currentTheme);
      setActiveThemeIndicator(this.el, this.currentTheme);
      updateLogoForTheme();
      writeTheme(this.currentTheme);
    };

    this.handleStorageChange = (event) => {
      if (event.key !== THEME_KEY) {
        return;
      }
      this.apply(event.newValue || "auto");
    };

    this.handleMediaChange = () => {
      if (this.currentTheme === "auto") {
        applyTheme("auto");
      }
    };

    this.handleThemeClick = (event) => {
      const button = event.target.closest("[data-theme-value]");
      if (!button || !this.el.contains(button)) {
        return;
      }
      this.apply(button.dataset.themeValue);
    };

    this.el.addEventListener("click", this.handleThemeClick);

    this.apply(this.currentTheme);
    this.matchMedia.addEventListener("change", this.handleMediaChange);
    window.addEventListener("storage", this.handleStorageChange);

    requestAnimationFrame(() => {
      document.documentElement.classList.remove("no-transition");
    });
  },

  reconnected() {
    this.apply(this.currentTheme);
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleThemeClick);
    this.matchMedia.removeEventListener("change", this.handleMediaChange);
    window.removeEventListener("storage", this.handleStorageChange);
  }
};

export default ThemeToggle;

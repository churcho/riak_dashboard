# Agent Instructions

This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- This project has no database — it pulls data from Riak servers via WebSocket streaming

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/riak_dashboard_web";

- **Always use and maintain this import syntax** in the app.css file
- **Never** use `@apply` when writing raw css
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline `<script>` tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions

## Dependency Management — Always Vendor

**Never use `npm install`, `yarn add`, or any package manager to add frontend dependencies.**

All JavaScript and CSS dependencies MUST be vendored directly into the project:

### JavaScript Libraries
- Place minified JS files in `assets/vendor/`
- Import in `assets/js/app.js` using relative paths: `import "../vendor/library-name"`
- Example: `import Choices from "../vendor/choices"` (Choices.js)

### CSS Libraries
- Place CSS files in `assets/css/vendor/`
- Import in `assets/css/app.css` using: `@import "./vendor/library-name.css";`
- Create theme override files alongside: `assets/css/vendor/library-theme.css`

### How to Vendor a New Dependency

1. Download the minified production build from CDN or GitHub releases
2. Place JS in `assets/vendor/`, CSS in `assets/css/vendor/`
3. Import JS in `assets/js/app.js`
4. Import CSS in `assets/css/app.css`
5. If the library needs LiveView integration, create a hook in `assets/js/hooks/`
6. Register the hook in `assets/js/app.js` in the `hooks` object

### Currently Vendored Libraries

| Library | JS Path | CSS Path | Hook |
|---------|---------|----------|------|
| Topbar | `assets/vendor/topbar.js` | — | — |
| DaisyUI | `assets/vendor/daisyui.js` | via @plugin | — |
| DaisyUI Theme | `assets/vendor/daisyui-theme.js` | via @plugin | — |
| Heroicons | `assets/vendor/heroicons.js` | via @plugin | — |
| Choices.js | `assets/vendor/choices.js` | `assets/css/vendor/choices.css` | `ChoicesSelect` |

### LiveView Hook Patterns

When creating hooks for vendored libraries:

1. **mounted()**: Initialize the library on the DOM element
2. **updated()**: Handle LiveView DOM patches — re-sync library state from data attributes
3. **destroyed()**: Clean up library instances to prevent memory leaks
4. **Never use `phx-update="ignore"`** if data can change — instead, sync via data attributes in `updated()`

### Theme Integration

All vendored UI libraries must be themed to match the OpenRiak design system:
- Use CSS custom properties from `assets/css/openriak_tokens.css`
- Support dark mode via `.dark` class on `<html>`
- Match the brand orange: `#e77117`
- Match card styling: white bg, `#EEEDEA` border, `0.5rem` border-radius

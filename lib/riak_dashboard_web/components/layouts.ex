defmodule RiakDashboardWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use RiakDashboardWeb, :html

  import RiakDashboardWeb.Components.Dashboard.Shell
  import RiakDashboardWeb.Components.Dashboard.Icons, only: [nav_icon: 1]

  embed_templates("layouts/*")

  def app(assigns) do
    ~H"""
    <div
      id="app-shell"
      phx-hook="SidebarShell"
      class="relative flex min-h-screen h-screen bg-[var(--or-bg-base)] text-[var(--or-fg-base)] overflow-x-hidden transition-colors duration-200"
    >
      <button
        type="button"
        data-sidebar-open
        aria-label="Open navigation"
        aria-controls="sidebar"
        class="fixed top-3 left-3 z-30 inline-flex h-9 w-9 items-center justify-center rounded-lg border border-[#EEECE8] bg-white text-[#5A5A5A] shadow-sm lg:hidden dark:border-[#334155] dark:bg-[#1E293B] dark:text-[#94A3B8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
      >
        <.nav_icon name="hamburger" class="h-[18px] w-[18px]" />
      </button>
      <div
        data-sidebar-overlay
        data-sidebar-close
        class="fixed inset-0 z-20 bg-black/40 opacity-0 pointer-events-none transition-opacity duration-200 lg:hidden"
        aria-hidden="true"
      />

      <.sidebar
        active_nav={assigns[:active_nav] || "Cluster"}
        cluster_name={assigns[:cluster_name]}
        remote_dcs={assigns[:remote_dcs] || []}
        cluster_selector_open={assigns[:cluster_selector_open] || false}
      />

      <main id="main-content" class="flex-1 overflow-y-auto p-4 pt-14 sm:p-6 sm:pt-14 lg:pt-6">
        <.breadcrumb_header
          active_nav={assigns[:active_nav]}
          page_title={assigns[:page_title] || "Dashboard"}
        />
        {@inner_content}
        <.flash_group flash={@flash} />
      </main>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Hang in there while we get back on track
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      id="theme-toggle"
      phx-hook="ThemeToggle"
      phx-update="ignore"
      data-theme="auto"
      class="theme-toggle relative flex flex-row items-center border border-[#E0DDD6] bg-[#F8FAFC] dark:bg-[#1E293B] dark:border-[#334155] w-24 h-7 transition-colors duration-200 rounded-lg mx-auto"
    >
      <div class="absolute w-[33%] h-full rounded-lg border border-[#E0DDD6] bg-[#F0EDE7] dark:border-[#334155] dark:bg-[#334155] left-0 [[data-theme=light]_&]:left-[33%] [[data-theme=auto]_&]:left-0 [[data-theme=dark]_&]:left-[66%] transition-[left]" />

      <button
        type="button"
        data-theme-value="auto"
        aria-label="Use system theme"
        class="relative z-10 flex-1 flex items-center justify-center p-1 focus:outline-none"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        data-theme-value="light"
        aria-label="Use light theme"
        class="relative z-10 flex-1 flex items-center justify-center p-1 focus:outline-none"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        data-theme-value="dark"
        aria-label="Use dark theme"
        class="relative z-10 flex-1 flex items-center justify-center p-1 focus:outline-none"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

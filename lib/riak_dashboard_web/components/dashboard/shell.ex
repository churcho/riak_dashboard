defmodule RiakDashboardWeb.Components.Dashboard.Shell do
  @moduledoc """
  Layout shell components for the Riak dashboard.

  Provides the sidebar navigation, header, and main content wrapper.
  These components handle responsive layout transitions between
  mobile drawer and desktop modes, using Fixoria-style hard-coded
  hex colors and daisyUI semantic classes.
  """

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.Icons
  import RiakDashboardWeb.CoreComponents, only: [icon: 1]

  @nav_sections [
    %{
      label: "MONITORING",
      items: [
        %{name: "Cluster", icon: "dashboard", path: "/"},
        %{name: "Ring", icon: "ring", path: "/ring"},
        %{name: "Nodes", icon: "server", path: "/nodes"},
        %{name: "Handoff", icon: "transfer", path: "/handoff"},
        %{name: "AAE", icon: "shield", path: "/aae"}
      ]
    },
    %{
      label: "DATA",
      items: [
        %{name: "Buckets", icon: "bucket", path: "/buckets"},
        %{name: "Counters", icon: "counter", path: "/counters"},
        %{name: "CRDTs", icon: "datatype", path: "/datatypes"},
        %{name: "MapReduce", icon: "mapreduce", path: "/mapred"},
        %{name: "Query", icon: "search", path: "/query"},
        %{name: "Index Query", icon: "search", path: "/query/index"}
      ]
    },
    %{
      label: "SETTINGS",
      items: [
        %{name: "Type Properties", icon: "settings", path: "/types"}
      ]
    }
  ]

  # -- Sidebar --

  attr(:active_nav, :string, required: true)
  attr(:mobile, :boolean, default: false)

  def sidebar(assigns) do
    assigns = assign(assigns, :nav_sections, @nav_sections)

    ~H"""
    <aside
      data-sidebar
      id="sidebar"
      class="fixed left-0 top-0 z-40 h-full w-[260px] min-w-[260px] -translate-x-full transform-gpu transition-transform duration-300 ease-[cubic-bezier(.16,1,.3,1)] border-r border-[#EEECE8] bg-[#FAFAF8] lg:static lg:z-auto lg:w-[220px] lg:min-w-[220px] lg:translate-x-0"
      role="navigation"
      aria-label="Main navigation"
      aria-hidden="true"
    >
      <.sidebar_content
        nav_sections={@nav_sections}
        active_nav={@active_nav}
        mobile={@mobile}
      />
    </aside>
    """
  end

  attr(:nav_sections, :list, required: true)
  attr(:active_nav, :string, required: true)
  attr(:mobile, :boolean, default: false)

  defp sidebar_content(assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col text-[13px] font-sans bg-[#FAFAF8] border-r border-[#EEECE8] transition-colors duration-200 dark:bg-[#1E293B] dark:border-[#334155]">
      <%!-- Logo --%>
      <div class="px-[18px] pt-6 pb-4 flex items-center justify-between">
        <a href="/" class="flex items-center gap-2 no-underline">
          <img
            src="/images/openriak_dashboard_logo.svg"
            alt="riak-dashboard"
            class="theme-logo h-14 w-auto max-w-[178px] object-contain transition-all duration-200"
            data-theme-image
          />
        </a>
        <button
          type="button"
          data-sidebar-close
          class="bg-transparent border-none cursor-pointer p-1 flex text-[#5A5A5A] hover:text-[#1A1A1A] lg:hidden dark:text-[#94A3B8] dark:hover:text-[#E2E8F0] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117] rounded transition-colors duration-200"
          aria-label="Close navigation"
        >
          <.nav_icon name="close" />
        </button>
      </div>

      <%!-- Navigation --%>
      <nav class="flex-1 overflow-y-auto px-2.5 scrollbar-hide" aria-label="Dashboard sections">
        <div :for={section <- @nav_sections}>
          <div class="px-2 pt-3.5 pb-1.5 text-[10px] font-semibold tracking-[1.2px] uppercase text-[#A8A8A8] dark:text-[#94A3B8]">
            {section.label}
          </div>
          <.link
            :for={item <- section.items}
            navigate={item.path}
            data-sidebar-link
            data-sidebar-close
            class={[
              "flex items-center gap-[9px] w-full py-[7px] px-2.5 rounded-lg text-[13px] no-underline transition-all duration-150 mb-px",
              "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
              if(@active_nav == item.name,
                do:
                  "border border-[#E0DDD6] bg-[#F0EDE7] text-[#1A1A1A] font-semibold dark:border-[#334155] dark:bg-[#334155] dark:text-[#F8FAFC]",
                else:
                  "border border-transparent bg-transparent text-[#5A5A5A] font-normal hover:bg-[#F5F3EF] dark:text-[#94A3B8] dark:hover:bg-[#243447]"
              )
            ]}
          >
            <span
              class="flex flex-shrink-0"
              style={if(@active_nav != item.name, do: "opacity: 0.6;", else: "")}
            >
              <.nav_icon name={item.icon} />
            </span>
            <span class={[
              "flex-1",
              if(@active_nav == item.name, do: "font-semibold", else: "font-normal")
            ]}>
              {item.name}
            </span>
          </.link>
        </div>
      </nav>

      <%!-- Bottom section --%>
      <div class="px-2.5 pb-3 pt-2 border-t border-[#EEECE8] dark:border-[#334155]">
        <.theme_toggle />
      </div>
    </div>
    """
  end

  # -- Theme Toggle --

  defp theme_toggle(assigns) do
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

  # -- Header --

  attr(:page_title, :string, required: true)
  attr(:mobile, :boolean, default: false)

  def dashboard_header(assigns) do
    ~H"""
    <header class="flex justify-between items-center gap-3 mb-6">
      <div class="flex items-center gap-2.5">
        <button
          :if={@mobile}
          data-sidebar-open
          class="w-9 h-9 rounded-lg cursor-pointer flex items-center justify-center flex-shrink-0 border border-[#EEECE8] bg-white text-[#5A5A5A] dark:border-[#334155] dark:bg-[#1E293B] dark:text-[#94A3B8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          aria-label="Open navigation menu"
        >
          <.nav_icon name="hamburger" />
        </button>
        <h1 class={[
          "font-bold tracking-tight text-[#1A1A1A] dark:text-[#E2E8F0]",
          if(@mobile, do: "text-[22px]", else: "text-[26px]")
        ]}>
          {@page_title}
        </h1>
      </div>
    </header>
    """
  end
end

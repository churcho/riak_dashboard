defmodule RiakDashboardWeb.Components.Dashboard.Cards do
  @moduledoc "Stat card components for displaying cluster metrics."

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.Icons
  import RiakDashboardWeb.CoreComponents, only: [badge: 1]

  attr(:title, :string, required: true)
  attr(:value, :any, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:status, :atom, default: nil)
  attr(:icon, :string, default: nil)
  attr(:icon_color, :string, default: "text-[#1A1A1A]/[0.06] dark:text-[#E2E8F0]/[0.08]")
  attr(:tooltip, :string, default: nil)

  def stat_card(assigns) do
    ~H"""
    <div
      class={["min-w-0", @tooltip && "tooltip tooltip-bottom"]}
      data-tip={@tooltip}
    >
      <div class="relative h-full bg-white rounded-xl border border-[#EEEDEA] px-3.5 py-3 overflow-hidden dark:bg-[#1f2937] dark:border-[#374151]">
        <div :if={@icon} class={"absolute -bottom-1.5 -right-1.5 pointer-events-none #{@icon_color}"}>
          <.nav_icon name={@icon} size={44} />
        </div>
        <div class="relative">
          <div class="text-[11px] text-[#8A8A8A] mb-1 dark:text-[#9CA3AF]">{@title}</div>
          <div class="flex items-center gap-1.5">
            <span class="text-lg font-bold font-heading text-[#1A1A1A] tracking-tight leading-none truncate dark:text-[#E2E8F0]">
              {@value}
            </span>
            <.badge :if={@status == :ok} variant={:success}>OK</.badge>
            <.badge :if={@status == :warning} variant={:warning}>Pending</.badge>
            <.badge :if={@status == :error} variant={:error}>Error</.badge>
          </div>
          <div class="mt-1.5 text-[10px] text-[#A5A5A5] truncate dark:text-[#6B7280]">
            {@subtitle}&nbsp;
          </div>
        </div>
      </div>
    </div>
    """
  end
end

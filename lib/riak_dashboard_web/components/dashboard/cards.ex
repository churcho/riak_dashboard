defmodule RiakDashboardWeb.Components.Dashboard.Cards do
  @moduledoc "Stat card components for displaying cluster metrics."

  use Phoenix.Component

  attr(:title, :string, required: true)
  attr(:value, :any, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:status, :atom, default: nil)

  def stat_card(assigns) do
    ~H"""
    <div class="flex-1 min-w-0 bg-white rounded-xl border border-[#EEEDEA] px-[18px] py-4">
      <div class="text-xs text-[#8A8A8A] mb-2">{@title}</div>
      <div class="flex items-center gap-2">
        <span class="text-[30px] font-bold text-[#1A1A1A] tracking-tight leading-none dark:text-[#E2E8F0]">
          {@value}
        </span>
        <span
          :if={@status == :ok}
          class="text-xs font-semibold text-[#4A7C59] bg-[#E8F5E9] px-2 py-0.5 rounded-full dark:text-[#34D399] dark:bg-[#0f3429]"
        >
          OK
        </span>
        <span
          :if={@status == :warning}
          class="text-xs font-semibold text-[#E69500] bg-[#FFF8E1] px-2 py-0.5 rounded-full dark:text-[#f59e0b] dark:bg-[#422006]"
        >
          Pending
        </span>
        <span
          :if={@status == :error}
          class="text-xs font-semibold text-[#C75050] bg-[#FFEBEE] px-2 py-0.5 rounded-full dark:text-[#f87171] dark:bg-[#3a1f22]"
        >
          Error
        </span>
      </div>
      <div :if={@subtitle} class="mt-2.5 text-[11px] text-[#A5A5A5]">
        {@subtitle}
      </div>
    </div>
    """
  end
end

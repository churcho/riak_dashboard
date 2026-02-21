defmodule RiakDashboardWeb.Components.Dashboard.Icons do
  @moduledoc """
  SVG icon components for the Riak dashboard navigation.

  Each icon renders as an inline SVG with configurable size and consistent
  stroke styling. Icons are designed to work at 18x18 default size.
  """

  use Phoenix.Component

  attr(:name, :string, required: true)
  attr(:size, :integer, default: 18)
  attr(:class, :string, default: "")

  def nav_icon(assigns) do
    ~H"""
    <svg
      width={@size}
      height={@size}
      viewBox="0 0 18 18"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={@class}
      aria-hidden="true"
    >
      <.icon_path name={@name} />
    </svg>
    """
  end

  # Grid/squares icon for Cluster overview
  defp icon_path(%{name: "dashboard"} = assigns) do
    ~H"""
    <rect x="2" y="2" width="5.5" height="5.5" rx="1.2" />
    <rect x="10.5" y="2" width="5.5" height="5.5" rx="1.2" />
    <rect x="2" y="10.5" width="5.5" height="5.5" rx="1.2" />
    <rect x="10.5" y="10.5" width="5.5" height="5.5" rx="1.2" />
    """
  end

  # Circle/donut icon for Ring visualization
  defp icon_path(%{name: "ring"} = assigns) do
    ~H"""
    <circle cx="9" cy="9" r="6.5" />
    <circle cx="9" cy="9" r="2.5" />
    """
  end

  # Server/monitor icon for Nodes
  defp icon_path(%{name: "server"} = assigns) do
    ~H"""
    <rect x="2.5" y="2" width="13" height="5" rx="1.5" />
    <rect x="2.5" y="11" width="13" height="5" rx="1.5" />
    <circle cx="5.5" cy="4.5" r="0.75" fill="currentColor" stroke="none" />
    <circle cx="5.5" cy="13.5" r="0.75" fill="currentColor" stroke="none" />
    <path d="M9 7v4" />
    """
  end

  # Arrows exchanging icon for Handoff
  defp icon_path(%{name: "transfer"} = assigns) do
    ~H"""
    <path d="M3 6h12M12 3l3 3-3 3" />
    <path d="M15 12H3M6 9l-3 3 3 3" />
    """
  end

  # Shield/check icon for AAE
  defp icon_path(%{name: "shield"} = assigns) do
    ~H"""
    <path d="M9 1.5L2.5 4.5v4c0 4.5 3 7.5 6.5 9 3.5-1.5 6.5-4.5 6.5-9v-4L9 1.5z" />
    <path d="M6.5 9l2 2 3.5-4" />
    """
  end

  # Bucket/database icon for Buckets/KV Browser
  defp icon_path(%{name: "bucket"} = assigns) do
    ~H"""
    <ellipse cx="9" cy="4" rx="6" ry="2.5" />
    <path d="M3 4v10c0 1.4 2.7 2.5 6 2.5s6-1.1 6-2.5V4" />
    <path d="M3 9c0 1.4 2.7 2.5 6 2.5s6-1.1 6-2.5" />
    """
  end

  # Plus-minus icon for Counters
  defp icon_path(%{name: "counter"} = assigns) do
    ~H"""
    <path d="M4 5h5M6.5 2.5v5" />
    <path d="M10 13h5" />
    <rect x="2" y="1" width="14" height="16" rx="2" />
    """
  end

  # Tree/structure icon for CRDTs
  defp icon_path(%{name: "datatype"} = assigns) do
    ~H"""
    <circle cx="9" cy="3" r="2" />
    <circle cx="4" cy="14" r="2" />
    <circle cx="14" cy="14" r="2" />
    <path d="M9 5v3M9 8l-5 4M9 8l5 4" />
    """
  end

  # Funnel/filter icon for MapReduce
  defp icon_path(%{name: "mapreduce"} = assigns) do
    ~H"""
    <path d="M2 3h14l-5 6v4l-4 2V9L2 3z" />
    """
  end

  # Magnifying glass for Index queries
  defp icon_path(%{name: "search"} = assigns) do
    ~H"""
    <circle cx="7.5" cy="7.5" r="5" />
    <path d="M11.5 11.5l4 4" stroke-width="2" />
    """
  end

  # Gear icon for Type Properties
  defp icon_path(%{name: "settings"} = assigns) do
    ~H"""
    <circle cx="9" cy="9" r="2.5" />
    <path d="M14.5 11a1 1 0 00.2 1.1l.1.1a1.2 1.2 0 01-1.7 1.7l-.1-.1a1 1 0 00-1.1-.2 1 1 0 00-.6.9v.3a1.2 1.2 0 01-2.4 0v-.2a1 1 0 00-.7-.9 1 1 0 00-1.1.2l-.1.1a1.2 1.2 0 01-1.7-1.7l.1-.1A1 1 0 005.5 11a1 1 0 00-.9-.6h-.3a1.2 1.2 0 010-2.4h.2a1 1 0 00.9-.7 1 1 0 00-.2-1.1l-.1-.1a1.2 1.2 0 011.7-1.7l.1.1a1 1 0 001.1.2h0a1 1 0 00.6-.9v-.3a1.2 1.2 0 012.4 0v.2a1 1 0 00.6.9 1 1 0 001.1-.2l.1-.1a1.2 1.2 0 011.7 1.7l-.1.1a1 1 0 00-.2 1.1v0a1 1 0 00.9.6h.3a1.2 1.2 0 010 2.4h-.2a1 1 0 00-.9.6z" />
    """
  end

  # Sun icon for light mode toggle
  defp icon_path(%{name: "sun"} = assigns) do
    ~H"""
    <circle cx="9" cy="9" r="3" />
    <path d="M9 2v2M9 14v2M2 9h2M14 9h2M4.2 4.2l1.4 1.4M12.4 12.4l1.4 1.4M4.2 13.8l1.4-1.4M12.4 5.6l1.4-1.4" />
    """
  end

  # Moon icon for dark mode toggle
  defp icon_path(%{name: "moon"} = assigns) do
    ~H"""
    <path d="M15 10.5A6.5 6.5 0 017.5 3 6.5 6.5 0 109 15.5a6.5 6.5 0 006-5z" />
    """
  end

  # Three lines for mobile menu toggle
  defp icon_path(%{name: "hamburger"} = assigns) do
    ~H"""
    <path d="M3 5h12M3 9h12M3 13h12" stroke-width="1.8" />
    """
  end

  # X icon for close
  defp icon_path(%{name: "close"} = assigns) do
    ~H"""
    <path d="M4 4l10 10M14 4L4 14" stroke-width="2" />
    """
  end

  # Chevron-down for dropdowns
  defp icon_path(%{name: "chevron-down"} = assigns) do
    ~H"""
    <path d="M4 7l5 5 5-5" stroke-width="1.8" />
    """
  end

  # Checkmark
  defp icon_path(%{name: "check"} = assigns) do
    ~H"""
    <path d="M4 9l3.5 3.5L14 5" stroke-width="2" />
    """
  end

  # X for errors
  defp icon_path(%{name: "x-mark"} = assigns) do
    ~H"""
    <path d="M5 5l8 8M13 5l-8 8" stroke-width="2" />
    """
  end

  # Circular arrows for refresh/reconnecting
  defp icon_path(%{name: "arrow-path"} = assigns) do
    ~H"""
    <path d="M3 9a6 6 0 0110.2-4.2M15 2v3h-3" />
    <path d="M15 9a6 6 0 01-10.2 4.2M3 16v-3h3" />
    """
  end

  # Fallback: simple rounded rectangle
  defp icon_path(%{name: _other} = assigns) do
    ~H"""
    <rect x="2" y="2" width="14" height="14" rx="2" />
    """
  end
end

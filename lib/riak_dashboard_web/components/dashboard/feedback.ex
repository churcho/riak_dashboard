defmodule RiakDashboardWeb.Components.Dashboard.Feedback do
  @moduledoc "Reusable feedback components for error banners and loading indicators."

  use Phoenix.Component

  attr :message, :string, required: true

  def error_banner(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-[#C75050] px-4 py-3 mb-4 text-sm text-[#C75050]">
      {@message}
    </div>
    """
  end

  attr :label, :string, required: true

  def loading_text(assigns) do
    ~H"""
    <p class="text-sm text-[#8A8A8A]">{@label}</p>
    """
  end
end

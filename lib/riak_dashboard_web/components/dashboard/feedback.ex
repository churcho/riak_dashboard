defmodule RiakDashboardWeb.Components.Dashboard.Feedback do
  @moduledoc "Reusable feedback components for alerts, error banners and loading indicators."

  use Phoenix.Component

  import RiakDashboardWeb.CoreComponents, only: [icon: 1]

  # -- Alert --

  attr :kind, :atom, default: :error, values: [:error, :success, :warning, :info]
  attr :message, :string, required: true
  attr :title, :string, default: nil
  attr :class, :string, default: ""

  def alert(assigns) do
    ~H"""
    <div
      class={[
        "flex items-start gap-3 rounded-xl px-4 py-3.5 mb-4 text-sm border",
        alert_classes(@kind),
        @class
      ]}
      role="alert"
    >
      <.icon name={alert_icon_name(@kind)} class="size-5 flex-shrink-0 mt-0.5" />
      <div class="flex-1 min-w-0">
        <p :if={@title} class="font-semibold mb-0.5">{@title}</p>
        <p class="break-words">{@message}</p>
      </div>
    </div>
    """
  end

  # -- Convenience wrappers --

  attr :message, :string, required: true

  def error_banner(assigns) do
    ~H"""
    <.alert kind={:error} message={@message} />
    """
  end

  attr :message, :string, required: true

  def success_banner(assigns) do
    ~H"""
    <.alert kind={:success} message={@message} />
    """
  end

  attr :message, :string, required: true

  def warning_banner(assigns) do
    ~H"""
    <.alert kind={:warning} message={@message} />
    """
  end

  attr :message, :string, required: true

  def info_banner(assigns) do
    ~H"""
    <.alert kind={:info} message={@message} />
    """
  end

  # -- Loading --

  attr :label, :string, required: true

  def loading_text(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5 py-6 text-sm text-[var(--or-fg-subtle)]">
      <.icon name="hero-arrow-path" class="size-4 motion-safe:animate-spin" />
      <p>{@label}</p>
    </div>
    """
  end

  # -- Helpers --

  defp alert_classes(:error),
    do: "bg-[var(--or-danger-bg)] text-[var(--or-danger-fg)] border-[var(--or-danger-border)]"

  defp alert_classes(:success),
    do: "bg-[var(--or-success-bg)] text-[var(--or-success-fg)] border-[var(--or-success-border)]"

  defp alert_classes(:warning),
    do: "bg-[var(--or-warning-bg)] text-[var(--or-warning-fg)] border-[var(--or-warning-border)]"

  defp alert_classes(:info),
    do: "bg-[var(--or-info-bg)] text-[var(--or-info-fg)] border-[var(--or-info-border)]"

  defp alert_icon_name(:error), do: "hero-exclamation-circle"
  defp alert_icon_name(:success), do: "hero-check-circle"
  defp alert_icon_name(:warning), do: "hero-exclamation-triangle"
  defp alert_icon_name(:info), do: "hero-information-circle"
end

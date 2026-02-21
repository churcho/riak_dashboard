defmodule RiakDashboardWeb.Components.Dashboard.ChoicesSelect do
  @moduledoc "Choices.js-powered select dropdown with LiveView hook integration."

  use Phoenix.Component

  attr :id, :string, required: true

  attr :options, :list,
    required: true,
    doc: "List of {label, value} tuples, %{value:, label:} maps, or plain strings"

  attr :selected, :string, default: nil
  attr :event, :string, required: true, doc: "LiveView event name to push on change"
  attr :value_key, :string, default: "value", doc: "Key name for the value in the event payload"
  attr :placeholder, :string, default: "Select..."
  attr :compact, :boolean, default: false
  attr :search_enabled, :boolean, default: true
  attr :class, :string, default: ""

  def choices_select(assigns) do
    options_json =
      assigns.options
      |> Enum.map(fn opt -> %{value: opt_value(opt), label: opt_label(opt)} end)
      |> Jason.encode!()

    assigns = assign(assigns, :options_json, options_json)

    ~H"""
    <div
      id={@id}
      phx-hook="ChoicesSelect"
      data-options={@options_json}
      data-selected={@selected}
      data-event={@event}
      data-value-key={@value_key}
      data-compact={to_string(@compact)}
      data-search-enabled={to_string(@search_enabled)}
      data-placeholder={@placeholder}
      class={@class}
    >
      <select></select>
    </div>
    """
  end

  defp opt_value({_label, value}), do: value
  defp opt_value(%{value: value}), do: value
  defp opt_value(value) when is_binary(value), do: value

  defp opt_label({label, _value}), do: label
  defp opt_label(%{label: label}), do: label
  defp opt_label(value) when is_binary(value), do: value
end

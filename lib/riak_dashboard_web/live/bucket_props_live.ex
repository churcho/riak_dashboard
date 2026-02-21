defmodule RiakDashboardWeb.BucketPropsLive do
  @moduledoc "Bucket properties viewer and editor for the KV browser."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Paths, only: [buckets_path: 1]

  @editable_props ~w(n_val allow_mult last_write_wins basic_quorum notfound_ok)

  @impl true
  def mount(params, _session, socket) do
    bucket = Map.fetch!(params, "bucket")
    type = Map.get(params, "type")
    opts = if type, do: [type: type], else: []

    socket =
      assign(socket,
        page_title: "Bucket Properties",
        active_nav: "Buckets",
        bucket: bucket,
        type: type,
        opts: opts,
        props: nil,
        editing: false,
        form_props: %{},
        loading: true,
        saving: false,
        resetting: false,
        error: nil,
        save_error: nil
      )

    socket =
      if connected?(socket) do
        load_props(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    editing = !socket.assigns.editing

    form_props =
      if editing and socket.assigns.props do
        socket.assigns.props
        |> Map.take(@editable_props)
        |> Map.new(fn {k, v} -> {k, to_string(v)} end)
      else
        socket.assigns.form_props
      end

    {:noreply, assign(socket, editing: editing, form_props: form_props, save_error: nil)}
  end

  def handle_event("update_prop", %{"prop" => prop, "value" => value}, socket) do
    form_props = Map.put(socket.assigns.form_props, prop, value)
    {:noreply, assign(socket, form_props: form_props)}
  end

  def handle_event("save_props", _params, socket) do
    client = Client.impl()
    base_url = Client.base_url()

    props = cast_form_props(socket.assigns.form_props)

    socket = assign(socket, saving: true, save_error: nil)

    case client.put_bucket_props(base_url, socket.assigns.bucket, props, socket.assigns.opts) do
      {:ok, _} ->
        socket =
          socket
          |> assign(editing: false, saving: false, save_error: nil)
          |> load_props()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, saving: false, save_error: "Save failed: #{inspect(reason)}")}
    end
  end

  def handle_event("reset_props", _params, socket) do
    client = Client.impl()
    base_url = Client.base_url()

    socket = assign(socket, resetting: true, save_error: nil)

    case client.delete_bucket_props(base_url, socket.assigns.bucket, socket.assigns.opts) do
      :ok ->
        socket =
          socket
          |> assign(editing: false, resetting: false, save_error: nil)
          |> load_props()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         assign(socket, resetting: false, save_error: "Reset failed: #{inspect(reason)}")}
    end
  end

  defp load_props(socket) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.get_bucket_props(base_url, socket.assigns.bucket, socket.assigns.opts) do
      {:ok, %{"props" => props}} ->
        assign(socket, props: props, loading: false)

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  defp cast_form_props(form_props) do
    Map.new(form_props, fn {key, value} ->
      {key, cast_value(key, value)}
    end)
  end

  defp cast_value("n_val", value), do: String.to_integer(value)

  defp cast_value(_key, "true"), do: true
  defp cast_value(_key, "false"), do: false
  defp cast_value(_key, value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Breadcrumbs --%>
      <nav class="flex items-center gap-1.5 text-sm mb-4 text-[#8A8A8A]">
        <.link
          navigate={buckets_path(@type)}
          class="text-[#e77117] no-underline"
        >
          Buckets
        </.link>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">{@bucket}</span>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">Properties</span>
      </nav>

      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">
          Properties for <code class="text-[#e77117]">{@bucket}</code>
        </h1>
        <div :if={@props} class="flex items-center gap-2">
          <button
            phx-click="toggle_edit"
            class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-white text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          >
            {if @editing, do: "Cancel", else: "Edit"}
          </button>
          <button
            phx-click="reset_props"
            data-confirm="Reset bucket properties to defaults?"
            disabled={@resetting}
            class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#C75050] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#C75050]"
          >
            {if @resetting, do: "Resetting...", else: "Reset"}
          </button>
        </div>
      </div>

      <.error_banner :if={@error} message={@error} />

      <.loading_text :if={@loading} label="Loading properties..." />

      <%= if @props && @editing do %>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4 mb-4">
          <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
            Edit Common Properties
          </h2>

          <%= if @save_error do %>
            <div class="px-3 py-2 mb-3 rounded text-sm text-[#C75050] bg-[#FFEBEE]">
              {@save_error}
            </div>
          <% end %>

          <form phx-submit="save_props" class="space-y-4">
            <%!-- n_val (integer input) --%>
            <div class="flex items-center gap-3">
              <label
                class="text-sm font-medium w-40 text-[#1A1A1A]"
                for="prop-n_val"
              >
                n_val
              </label>
              <input
                type="number"
                id="prop-n_val"
                min="1"
                value={@form_props["n_val"]}
                phx-blur="update_prop"
                phx-value-prop="n_val"
                class="px-3 py-1.5 rounded-lg text-sm w-24 border border-[#EEECE8] bg-white text-[#1A1A1A]"
              />
            </div>

            <%!-- Boolean props --%>
            <div
              :for={prop <- ~w(allow_mult last_write_wins basic_quorum notfound_ok)}
              class="flex items-center gap-3"
            >
              <label
                class="text-sm font-medium w-40 text-[#1A1A1A]"
                for={"prop-#{prop}"}
              >
                {prop}
              </label>
              <select
                id={"prop-#{prop}"}
                phx-change="update_prop"
                phx-value-prop={prop}
                name="value"
                class="px-3 py-1.5 rounded-lg text-sm border border-[#EEECE8] bg-white text-[#1A1A1A]"
              >
                <option value="true" selected={@form_props[prop] == "true"}>true</option>
                <option value="false" selected={@form_props[prop] == "false"}>false</option>
              </select>
            </div>

            <div class="flex justify-end pt-2">
              <button
                type="submit"
                disabled={@saving}
                class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              >
                {if @saving, do: "Saving...", else: "Save Properties"}
              </button>
            </div>
          </form>
        </div>
      <% end %>

      <%= if @props do %>
        <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden">
          <table class="w-full text-sm" style="border-collapse: collapse;">
            <thead>
              <tr class="border-b border-[#EEECE8]">
                <th class="text-left px-4 py-3 font-semibold text-[#8A8A8A] bg-white">
                  Property
                </th>
                <th class="text-left px-4 py-3 font-semibold text-[#8A8A8A] bg-white">
                  Value
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={{key, value} <- Enum.sort(@props)}
                class="border-b border-[#EEECE8]"
              >
                <td class="px-4 py-2.5 font-mono text-[#1A1A1A]">
                  {key}
                </td>
                <td class="px-4 py-2.5 font-mono text-[#1A1A1A]">
                  {format_value(value)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_value(value) when is_boolean(value), do: to_string(value)
  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)
end

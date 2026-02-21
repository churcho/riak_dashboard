defmodule RiakDashboardWeb.ObjectLive do
  @moduledoc "Object detail view with metadata display, JSON editing, and delete support."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Formatters, only: [format_value: 1]
  import RiakDashboardWeb.Paths

  @impl true
  def mount(params, _session, socket) do
    bucket = Map.fetch!(params, "bucket")
    key = Map.fetch!(params, "key")
    type = Map.get(params, "type")
    opts = if type, do: [type: type], else: []

    socket =
      assign(socket,
        page_title: key,
        active_nav: "Buckets",
        bucket: bucket,
        key: key,
        type: type,
        opts: opts,
        object: nil,
        loading: true,
        editing: false,
        edit_value: "",
        edit_content_type: "application/json",
        save_error: nil,
        error: nil
      )

    socket =
      if connected?(socket) do
        load_object(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    editing = !socket.assigns.editing

    edit_value =
      if editing and socket.assigns.object do
        format_value(socket.assigns.object["value"])
      else
        socket.assigns.edit_value
      end

    {:noreply,
     assign(socket,
       editing: editing,
       edit_value: edit_value,
       edit_content_type:
         (socket.assigns.object && socket.assigns.object["content_type"]) || "application/json",
       save_error: nil
     )}
  end

  def handle_event("save", %{"value" => raw_json, "content_type" => content_type}, socket) do
    case parse_save_value(raw_json, content_type) do
      {:ok, value} ->
        do_save(socket, value, content_type)

      {:error, message} ->
        {:noreply, assign(socket, save_error: message)}
    end
  end

  def handle_event("delete", _params, socket) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.delete_object(
           base_url,
           socket.assigns.bucket,
           socket.assigns.key,
           socket.assigns.opts
         ) do
      :ok ->
        {:noreply,
         push_navigate(socket, to: keys_path(socket.assigns.type, socket.assigns.bucket))}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Delete failed: #{inspect(reason)}")}
    end
  end

  defp load_object(socket) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.get_object(
           base_url,
           socket.assigns.bucket,
           socket.assigns.key,
           socket.assigns.opts
         ) do
      {:ok, object} ->
        assign(socket, object: object, loading: false)

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  defp parse_save_value(raw, content_type) do
    case Jason.decode(raw) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, %Jason.DecodeError{} = err} ->
        if content_type in ["text/plain", "application/octet-stream"] do
          {:ok, raw}
        else
          {:error, "Invalid JSON: #{Exception.message(err)}"}
        end
    end
  end

  defp do_save(socket, value, content_type) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.put_object(
           base_url,
           socket.assigns.bucket,
           socket.assigns.key,
           value,
           Keyword.merge(socket.assigns.opts,
             content_type: content_type,
             vclock: socket.assigns.object["vclock"]
           )
         ) do
      {:ok, _} ->
        socket =
          socket
          |> assign(editing: false, save_error: nil)
          |> load_object()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, save_error: "Save failed: #{inspect(reason)}")}
    end
  end

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
        <.link
          navigate={keys_path(@type, @bucket)}
          class="text-[#e77117] no-underline"
        >
          {@bucket}
        </.link>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">{@key}</span>
      </nav>

      <div class="flex items-center justify-end flex-wrap gap-3 mb-6">
        <div class="flex items-center gap-2">
          <button
            phx-click="toggle_edit"
            class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-white text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          >
            {if @editing, do: "Cancel", else: "Edit"}
          </button>
          <button
            phx-click="delete"
            data-confirm="Are you sure you want to delete this object? This cannot be undone."
            class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#C75050] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          >
            Delete
          </button>
        </div>
      </div>

      <.error_banner :if={@error} message={@error} />

      <.loading_text :if={@loading} label="Loading object..." />

      <%= if @object do %>
        <%!-- Metadata Section --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4 mb-4">
          <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Metadata</h2>
          <dl class="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
            <div>
              <dt class="font-medium text-[#8A8A8A]">Content-Type</dt>
              <dd class="text-[#1A1A1A]">{@object["content_type"]}</dd>
            </div>
            <div>
              <dt class="font-medium text-[#8A8A8A]">VClock</dt>
              <dd class="font-mono text-xs break-all text-[#1A1A1A]">
                {@object["vclock"] || "-"}
              </dd>
            </div>
            <div>
              <dt class="font-medium text-[#8A8A8A]">Last Modified</dt>
              <dd class="text-[#1A1A1A]">{@object["last_modified"] || "-"}</dd>
            </div>
            <div>
              <dt class="font-medium text-[#8A8A8A]">ETag</dt>
              <dd class="font-mono text-xs break-all text-[#1A1A1A]">{@object["etag"] || "-"}</dd>
            </div>
          </dl>
        </div>

        <%!-- Value Section --%>
        <%= if @editing do %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4">
            <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
              Edit Value
            </h2>

            <%= if @save_error do %>
              <div class="px-3 py-2 mb-3 rounded text-sm text-[#C75050] bg-[#FFEBEE]">
                {@save_error}
              </div>
            <% end %>

            <form phx-submit="save">
              <div class="mb-3">
                <label class="block text-xs mb-1 text-[#8A8A8A]">Content-Type</label>
                <input
                  type="text"
                  name="content_type"
                  value={@edit_content_type}
                  class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
                />
              </div>
              <textarea
                name="value"
                rows="16"
                class="w-full font-mono text-sm rounded-lg px-3 py-2 bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
                style="resize: vertical;"
              >{@edit_value}</textarea>
              <div class="flex justify-end mt-3">
                <button
                  type="submit"
                  class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        <% else %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4">
            <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Value</h2>
            <pre class="text-sm font-mono whitespace-pre-wrap rounded-lg px-4 py-3 overflow-x-auto bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8]">{format_value(@object["value"])}</pre>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end

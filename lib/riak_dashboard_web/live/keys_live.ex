defmodule RiakDashboardWeb.KeysLive do
  @moduledoc "Lists keys within a Riak bucket, with optional bucket-type support."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Paths

  @impl true
  def mount(params, _session, socket) do
    bucket = Map.fetch!(params, "bucket")
    type = Map.get(params, "type")
    opts = if type, do: [type: type], else: []

    socket =
      assign(socket,
        page_title: bucket,
        active_nav: "Buckets",
        bucket: bucket,
        type: type,
        opts: opts,
        keys: nil,
        loading: false,
        error: nil,
        creating: false,
        create_value: "{\n  \"hello\": \"riak\"\n}",
        create_content_type: "application/json",
        create_error: nil
      )

    socket =
      if connected?(socket) do
        load_keys(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("list_keys", _params, socket) do
    {:noreply, load_keys(socket)}
  end

  def handle_event(
        "create_object",
        %{"value" => raw_value, "content_type" => content_type},
        socket
      ) do
    socket =
      assign(socket,
        create_value: raw_value,
        create_content_type: content_type,
        create_error: nil
      )

    client = Client.impl()
    base_url = Client.base_url()

    with {:ok, value} <- maybe_parse_create_value(raw_value, content_type),
         {:ok, created} <-
           client.create_object(
             base_url,
             socket.assigns.bucket,
             value,
             Keyword.merge(socket.assigns.opts, content_type: content_type)
           ) do
      location = created["location"]
      key = location && List.last(String.split(location, "/"))

      socket =
        socket
        |> assign(create_error: nil)
        |> load_keys()

      if is_binary(key) and key != "" do
        {:noreply,
         push_navigate(socket, to: object_path(socket.assigns.type, socket.assigns.bucket, key))}
      else
        {:noreply, socket}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, create_error: inspect(reason))}
    end
  end

  defp maybe_parse_create_value(raw_value, content_type)
       when content_type in ["text/plain", "application/octet-stream"] do
    {:ok, raw_value}
  end

  defp maybe_parse_create_value(raw_value, _content_type) do
    Jason.decode(raw_value)
  end

  defp load_keys(socket) do
    socket = assign(socket, loading: true, error: nil)
    client = Client.impl()
    base_url = Client.base_url()

    case client.list_keys(base_url, socket.assigns.bucket, socket.assigns.opts) do
      {:ok, %{"keys" => keys}} ->
        assign(socket, keys: keys, loading: false)

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Breadcrumbs --%>
      <nav class="flex items-center gap-1.5 text-sm mb-4 text-[#8A8A8A]">
        <.link navigate={buckets_path(@type)} class="text-[#e77117] no-underline">
          Buckets
        </.link>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">{@bucket}</span>
      </nav>

      <div class="flex items-center justify-end flex-wrap gap-3 mb-6">
        <div class="flex items-center gap-2">
          <button
            phx-click="list_keys"
            disabled={@loading}
            class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            title="Listing keys is an expensive operation on production clusters"
          >
            <%= if @loading do %>
              Loading...
            <% else %>
              Reload Keys
            <% end %>
          </button>
        </div>
      </div>

      <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 mb-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
          Create Object (Server-Generated Key)
        </h2>

        <%= if @create_error do %>
          <div class="px-3 py-2 mb-3 rounded text-sm text-[#C75050] bg-[#FFEBEE]">
            {@create_error}
          </div>
        <% end %>

        <form phx-submit="create_object" class="space-y-3">
          <div>
            <label class="block text-xs mb-1 text-[#8A8A8A]">Content-Type</label>
            <input
              type="text"
              name="content_type"
              value={@create_content_type}
              class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
          </div>
          <textarea
            name="value"
            rows="5"
            class="w-full font-mono text-sm rounded-lg px-3 py-2 bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            style="resize: vertical;"
          >{@create_value}</textarea>
          <div class="flex justify-end">
            <button
              type="submit"
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#4A7C59] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#4A7C59]"
            >
              Create
            </button>
          </div>
        </form>
      </div>

      <%= if @error do %>
        <div class="bg-white rounded-xl border border-[#C75050] px-4 py-3 mb-4 text-sm text-[#C75050]">
          Failed to list keys: {@error}
        </div>
      <% end %>

      <.loading_text :if={@loading and is_nil(@keys)} label="Loading keys..." />

      <%= if @keys == [] do %>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 text-center">
          <p class="text-sm text-[#8A8A8A]">
            No keys found in this bucket.
          </p>
        </div>
      <% end %>

      <%= if @keys && @keys != [] do %>
        <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden">
          <table class="w-full text-sm" style="border-collapse: collapse;">
            <thead>
              <tr class="border-b border-[#EEECE8]">
                <th class="text-left px-4 py-3 font-semibold text-[#8A8A8A] bg-white">
                  Key
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={key <- @keys}
                class="border-b border-[#EEECE8]"
              >
                <td class="px-4 py-2.5">
                  <.link
                    navigate={object_path(@type, @bucket, key)}
                    class="text-[#e77117] no-underline"
                  >
                    {key}
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-xs mt-2 text-[#8A8A8A]">
          {length(@keys)} key(s) found
        </p>
      <% end %>
    </div>
    """
  end
end

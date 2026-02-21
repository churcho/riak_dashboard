defmodule RiakDashboardWeb.CrdtLive do
  @moduledoc "CRDT datatype detail view with value display and update operations."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback

  @impl true
  def mount(params, _session, socket) do
    case {params["type"], params["bucket"], params["key"]} do
      {type, bucket, key} when is_binary(type) and is_binary(bucket) and is_binary(key) ->
        socket =
          assign(socket,
            page_title: key,
            active_nav: "CRDTs",
            type: type,
            bucket: bucket,
            key: key,
            value: nil,
            context: nil,
            crdt_type: nil,
            loading: true,
            error: nil,
            update_input: "",
            update_success: false,
            lookup_type: type,
            lookup_bucket: bucket,
            lookup_key: key,
            create_input: "{\"increment\": 1}",
            live_action: :show
          )

        socket =
          if connected?(socket) do
            load_crdt(socket)
          else
            socket
          end

        {:ok, socket}

      _ ->
        {:ok,
         assign(socket,
           page_title: "CRDTs",
           active_nav: "CRDTs",
           type: nil,
           bucket: nil,
           key: nil,
           value: nil,
           context: nil,
           crdt_type: nil,
           loading: false,
           error: nil,
           update_input: "",
           update_success: false,
           lookup_type: "counters",
           lookup_bucket: "visits",
           lookup_key: "page1",
           create_input: "{\"increment\": 1}",
           live_action: :index
         )}
    end
  end

  @impl true
  def handle_event("submit_update", %{"update" => raw_json}, socket) do
    case Jason.decode(raw_json) do
      {:ok, update_map} ->
        client = Client.impl()
        base_url = Client.base_url()

        case client.update_crdt(
               base_url,
               socket.assigns.type,
               socket.assigns.bucket,
               socket.assigns.key,
               update_map,
               []
             ) do
          {:ok, _} ->
            socket =
              socket
              |> assign(error: nil, update_input: "", update_success: true)
              |> load_crdt()

            {:noreply, socket}

          {:error, reason} ->
            {:noreply,
             assign(socket, error: "Update failed: #{inspect(reason)}", update_success: false)}
        end

      {:error, _} ->
        {:noreply, assign(socket, error: "Invalid JSON", update_success: false)}
    end
  end

  def handle_event("reload", _params, socket) do
    {:noreply, load_crdt(assign(socket, error: nil, update_success: false))}
  end

  def handle_event("open_crdt", %{"type" => type, "bucket" => bucket, "key" => key}, socket) do
    type = String.trim(type)
    bucket = String.trim(bucket)
    key = String.trim(key)

    if type == "" or bucket == "" or key == "" do
      {:noreply, assign(socket, error: "Type, bucket, and key are required")}
    else
      {:noreply,
       push_navigate(
         socket,
         to:
           "/types/#{URI.encode(type)}/buckets/#{URI.encode(bucket)}/datatypes/#{URI.encode(key)}"
       )}
    end
  end

  def handle_event(
        "create_crdt",
        %{"type" => type, "bucket" => bucket, "update" => raw_update},
        socket
      ) do
    type = String.trim(type)
    bucket = String.trim(bucket)

    with false <- type == "" or bucket == "",
         {:ok, update} <- Jason.decode(raw_update),
         {:ok, created} <- Client.impl().create_crdt(Client.base_url(), type, bucket, update, []),
         location when is_binary(location) <- created["location"],
         key when is_binary(key) <- List.last(String.split(location, "/")) do
      {:noreply,
       push_navigate(
         assign(socket, error: nil, create_input: raw_update),
         to:
           "/types/#{URI.encode(type)}/buckets/#{URI.encode(bucket)}/datatypes/#{URI.encode(key)}"
       )}
    else
      true ->
        {:noreply, assign(socket, error: "Type and bucket are required")}

      {:error, reason} ->
        {:noreply,
         assign(socket, error: "Create failed: #{inspect(reason)}", create_input: raw_update)}

      _ ->
        {:noreply,
         assign(socket, error: "Create failed: location header missing", create_input: raw_update)}
    end
  end

  defp load_crdt(socket) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.get_crdt(
           base_url,
           socket.assigns.type,
           socket.assigns.bucket,
           socket.assigns.key,
           []
         ) do
      {:ok, data} ->
        assign(socket,
          value: data["value"],
          context: data["context"],
          crdt_type: data["type"],
          loading: false
        )

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">CRDTs</h1>
      </div>

      <.error_banner :if={@error} message={@error} />

      <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 mb-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Open Existing CRDT</h2>
        <form phx-submit="open_crdt" class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <input
            type="text"
            name="type"
            value={@lookup_type}
            placeholder="Bucket type"
            class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          />
          <input
            type="text"
            name="bucket"
            value={@lookup_bucket}
            placeholder="Bucket"
            class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          />
          <input
            type="text"
            name="key"
            value={@lookup_key}
            placeholder="Key"
            class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          />
          <div class="sm:col-span-3 flex justify-end">
            <button
              type="submit"
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            >
              Open
            </button>
          </div>
        </form>
      </div>

      <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
          Create New CRDT (Server-Generated Key)
        </h2>
        <form phx-submit="create_crdt" class="space-y-3">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <input
              type="text"
              name="type"
              value={@lookup_type}
              placeholder="Bucket type"
              class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
            <input
              type="text"
              name="bucket"
              value={@lookup_bucket}
              placeholder="Bucket"
              class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
          </div>
          <textarea
            name="update"
            rows="4"
            class="w-full px-3 py-2 rounded-lg text-sm font-mono bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            style="resize: vertical;"
          >{@create_input}</textarea>
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
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <%!-- Breadcrumbs --%>
      <nav class="flex items-center gap-1.5 text-sm mb-4 text-[#8A8A8A]">
        <span class="text-[#e77117]">CRDTs</span>
        <span>/</span>
        <span class="text-[#e77117]">{@type}</span>
        <span>/</span>
        <span class="text-[#e77117]">{@bucket}</span>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">{@key}</span>
      </nav>

      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-[#1A1A1A]">
            {@key}
          </h1>
          <%= if @crdt_type do %>
            <span class="px-2 py-0.5 rounded text-xs font-medium bg-white text-[#e77117] border border-[#EEECE8]">
              {@crdt_type}
            </span>
          <% end %>
        </div>
        <button
          phx-click="reload"
          class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-white text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
        >
          Reload
        </button>
      </div>

      <.error_banner :if={@error} message={@error} />

      <%= if @update_success do %>
        <div class="bg-white rounded-xl border border-[#C4E6C9] px-4 py-3 mb-4 text-sm text-[#4A7C59]">
          Update applied successfully.
        </div>
      <% end %>

      <.loading_text :if={@loading} label="Loading CRDT value..." />

      <%= if @value != nil do %>
        <%!-- Current Value --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 mb-6 text-center">
          <p class="text-sm font-medium mb-2 text-[#8A8A8A]">Current Value</p>
          <p class="text-5xl font-bold font-mono text-[#1A1A1A]">
            {format_value(@value)}
          </p>
        </div>

        <%!-- Context --%>
        <%= if @context do %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4 mb-6">
            <h2 class="text-sm font-semibold mb-2 text-[#8A8A8A]">Context</h2>
            <pre class="text-xs font-mono break-all whitespace-pre-wrap text-[#1A1A1A]">{@context}</pre>
          </div>
        <% end %>

        <%!-- Update Form --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4">
          <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
            Update Operation
          </h2>
          <form phx-submit="submit_update" class="flex flex-col gap-3">
            <textarea
              name="update"
              value={@update_input}
              placeholder="{&quot;increment&quot;: 1}"
              rows="4"
              class="w-full px-3 py-2 rounded-lg text-sm font-mono bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              style="resize: vertical;"
            ></textarea>
            <div class="flex justify-end">
              <button
                type="submit"
                class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              >
                Submit
              </button>
            </div>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_value(value) when is_map(value) or is_list(value) do
    Jason.encode!(value, pretty: true)
  end

  defp format_value(value), do: to_string(value)
end

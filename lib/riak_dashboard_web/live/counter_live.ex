defmodule RiakDashboardWeb.CounterLive do
  @moduledoc "Counter detail view with increment, decrement, and custom delta operations."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback

  @impl true
  def mount(params, _session, socket) do
    case {params["bucket"], params["key"]} do
      {bucket, key} when is_binary(bucket) and is_binary(key) ->
        socket =
          assign(socket,
            page_title: key,
            active_nav: "Counters",
            bucket: bucket,
            key: key,
            value: nil,
            loading: true,
            error: nil,
            delta_input: "",
            lookup_bucket: bucket,
            lookup_key: key,
            live_action: :show
          )

        socket =
          if connected?(socket) do
            load_counter(socket)
          else
            socket
          end

        {:ok, socket}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Counters",
           active_nav: "Counters",
           bucket: nil,
           key: nil,
           value: nil,
           loading: false,
           error: nil,
           delta_input: "",
           lookup_bucket: "scores",
           lookup_key: "player1",
           live_action: :index
         )}
    end
  end

  @impl true
  def handle_event("increment", _params, socket) do
    socket = apply_delta(socket, 1)
    {:noreply, socket}
  end

  def handle_event("decrement", _params, socket) do
    socket = apply_delta(socket, -1)
    {:noreply, socket}
  end

  def handle_event("apply_delta", %{"delta" => raw_delta}, socket) do
    case Integer.parse(raw_delta) do
      {delta, ""} ->
        socket =
          socket
          |> apply_delta(delta)
          |> assign(delta_input: "")

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, error: "Delta must be a valid integer")}
    end
  end

  def handle_event("open_counter", %{"bucket" => bucket, "key" => key}, socket) do
    bucket = String.trim(bucket)
    key = String.trim(key)

    if bucket == "" or key == "" do
      {:noreply, assign(socket, error: "Bucket and key are required")}
    else
      {:noreply,
       push_navigate(socket, to: "/buckets/#{URI.encode(bucket)}/counters/#{URI.encode(key)}")}
    end
  end

  defp apply_delta(socket, delta) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.update_counter(
           base_url,
           socket.assigns.bucket,
           socket.assigns.key,
           delta,
           []
         ) do
      :ok ->
        load_counter(assign(socket, error: nil))

      {:error, reason} ->
        assign(socket, error: "Update failed: #{inspect(reason)}")
    end
  end

  defp load_counter(socket) do
    client = Client.impl()
    base_url = Client.base_url()

    case client.get_counter(
           base_url,
           socket.assigns.bucket,
           socket.assigns.key,
           []
         ) do
      {:ok, value} ->
        assign(socket, value: value, loading: false)

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">Counters</h1>
      </div>

      <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Open Counter</h2>
        <form phx-submit="open_counter" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <input
            type="text"
            name="bucket"
            value={@lookup_bucket}
            placeholder="Bucket name"
            class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          />
          <input
            type="text"
            name="key"
            value={@lookup_key}
            placeholder="Counter key"
            class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          />
          <div class="sm:col-span-2 flex justify-end">
            <button
              type="submit"
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            >
              Open
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
        <span class="text-[#e77117]">Counters</span>
        <span>/</span>
        <span class="text-[#e77117]">{@bucket}</span>
        <span>/</span>
        <span class="text-[#1A1A1A] font-medium">{@key}</span>
      </nav>

      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">
          {@key}
        </h1>
      </div>

      <.error_banner :if={@error} message={@error} />

      <.loading_text :if={@loading} label="Loading counter..." />

      <%= if @value != nil do %>
        <%!-- Current Value --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 mb-6 text-center">
          <p class="text-sm font-medium mb-2 text-[#8A8A8A]">Current Value</p>
          <p class="text-5xl font-bold font-mono text-[#1A1A1A]">{@value}</p>
        </div>

        <%!-- Increment / Decrement Buttons --%>
        <div class="flex items-center justify-center gap-4 mb-6">
          <button
            phx-click="decrement"
            class="px-6 py-2 rounded-lg text-sm font-medium cursor-pointer bg-white text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          >
            -1
          </button>
          <button
            phx-click="increment"
            class="px-6 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
          >
            +1
          </button>
        </div>

        <%!-- Custom Delta Form --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4">
          <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
            Custom Delta
          </h2>
          <form phx-submit="apply_delta" class="flex items-center gap-3">
            <input
              type="text"
              name="delta"
              value={@delta_input}
              placeholder="e.g. 10 or -5"
              class="flex-1 px-3 py-2 rounded-lg text-sm font-mono bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
            <button
              type="submit"
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            >
              Apply
            </button>
          </form>
        </div>
      <% end %>
    </div>
    """
  end
end

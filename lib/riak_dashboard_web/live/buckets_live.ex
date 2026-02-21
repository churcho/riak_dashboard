defmodule RiakDashboardWeb.BucketsLive do
  @moduledoc "Bucket listing view for the KV browser."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Paths

  @impl true
  def mount(params, _session, socket) do
    bucket_type = Map.get(params, "type", "default")

    socket =
      assign(socket,
        page_title: "Buckets",
        active_nav: "Buckets",
        buckets: nil,
        bucket_type: bucket_type,
        loading: false,
        error: nil
      )

    # Auto-load buckets on mount in connected state
    socket =
      if connected?(socket) do
        load_buckets(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("list_buckets", _, socket) do
    {:noreply, load_buckets(socket)}
  end

  def handle_event("update_type", %{"type" => type}, socket) do
    bucket_type = String.trim(type)

    {:noreply,
     assign(socket, bucket_type: if(bucket_type == "", do: "default", else: bucket_type))}
  end

  defp load_buckets(socket) do
    socket = assign(socket, loading: true, error: nil)
    client = Client.impl()
    base_url = Client.base_url()
    type = socket.assigns.bucket_type

    opts = if type != "default", do: [type: type], else: []

    case client.list_buckets(base_url, opts) do
      {:ok, %{"buckets" => buckets}} ->
        assign(socket, buckets: buckets, loading: false)

      {:error, reason} ->
        assign(socket, error: inspect(reason), loading: false)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">Buckets</h1>
      </div>

      <%!-- Controls --%>
      <div class="flex items-center gap-3 mb-4">
        <div class="flex items-center gap-2">
          <label class="text-sm font-medium text-[#8A8A8A]">Type:</label>
          <input
            type="text"
            name="type"
            value={@bucket_type}
            phx-change="update_type"
            class="px-3 py-1.5 rounded-lg text-sm border border-[#EEECE8] bg-white text-[#1A1A1A]"
            placeholder="default"
          />
        </div>
        <button
          phx-click="list_buckets"
          class="px-4 py-1.5 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none"
          disabled={@loading}
        >
          {if @loading, do: "Loading...", else: "List Buckets"}
        </button>
      </div>

      <p class="text-xs mb-4 text-[#A8A8A8]">
        Warning: Listing buckets performs a full scan and can be expensive on large clusters.
      </p>

      <%!-- Error state --%>
      <div
        :if={@error}
        class="bg-white rounded-xl border border-[#C75050] px-4 py-3 mb-4"
      >
        <p class="text-sm text-[#C75050]">{@error}</p>
      </div>

      <%!-- Bucket count --%>
      <div :if={@buckets} class="mb-4">
        <.stat_card title="Buckets Found" value={length(@buckets)} />
      </div>

      <%!-- Bucket table --%>
      <div
        :if={@buckets && @buckets != []}
        class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden"
      >
        <table class="w-full">
          <thead>
            <tr class="bg-[#F5F3EF]">
              <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
                Bucket Name
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={bucket <- @buckets} class="border-t border-[#F0EFEB]">
              <td class="px-4 py-3 font-mono text-sm">
                <.link
                  navigate={keys_path(@bucket_type, bucket)}
                  class="text-primary hover:underline"
                >
                  {bucket}
                </.link>
              </td>
              <td class="px-4 py-3 text-sm">
                <.link
                  navigate={bucket_props_path(@bucket_type, bucket)}
                  class="text-[#8A8A8A] hover:underline text-xs"
                >
                  Properties
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- Empty state --%>
      <div
        :if={@buckets == []}
        class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 text-center"
      >
        <p class="text-sm text-[#8A8A8A]">No buckets found.</p>
      </div>
    </div>
    """
  end
end

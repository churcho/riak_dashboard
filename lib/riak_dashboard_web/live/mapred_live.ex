defmodule RiakDashboardWeb.MapredLive do
  @moduledoc "LiveView for building and running Riak MapReduce queries."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  @example_query Jason.encode!(
                   %{
                     "inputs" => "users",
                     "query" => [
                       %{
                         "map" => %{
                           "language" => "javascript",
                           "source" => "function(v) { return [1]; }"
                         }
                       }
                     ]
                   },
                   pretty: true
                 )

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "MapReduce",
        active_nav: "MapReduce",
        query_text: @example_query,
        results: nil,
        error: nil,
        running: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("run_query", %{"query" => query_text}, socket) do
    socket = assign(socket, query_text: query_text, running: true, error: nil, results: nil)

    case Jason.decode(query_text) do
      {:ok, query} ->
        client = Client.impl()
        base_url = Client.base_url()

        case client.run_mapred(base_url, query, []) do
          {:ok, results} ->
            {:noreply, assign(socket, results: results, running: false)}

          {:error, reason} ->
            {:noreply, assign(socket, error: "Query failed: #{inspect(reason)}", running: false)}
        end

      {:error, %Jason.DecodeError{} = err} ->
        {:noreply,
         assign(socket, error: "Invalid JSON: #{Exception.message(err)}", running: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Query input panel --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
          <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">Query</h2>
          <form phx-submit="run_query">
            <textarea
              name="query"
              rows="14"
              class="w-full font-mono text-sm rounded-lg p-3 bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              style="resize: vertical;"
              spellcheck="false"
            >{@query_text}</textarea>
            <button
              type="submit"
              disabled={@running}
              class="mt-3 px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117] disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <%= if @running do %>
                Running...
              <% else %>
                Run Query
              <% end %>
            </button>
          </form>
        </div>

        <%!-- Results panel --%>
        <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
          <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">Results</h2>

          <%= if @error do %>
            <div class="rounded-lg p-3 text-sm mb-3 bg-[#FFEBEE] text-[#C75050] border border-[#C75050]">
              {@error}
            </div>
          <% end %>

          <%= if @results do %>
            <pre class="font-mono text-sm rounded-lg p-3 overflow-auto max-h-[500px] bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8]">{Jason.encode!(@results, pretty: true)}</pre>
          <% end %>

          <%= if is_nil(@results) and is_nil(@error) do %>
            <p class="text-sm text-[#8A8A8A]">
              Submit a query to see results here.
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

defmodule RiakDashboardWeb.QueryLive do
  @moduledoc "Complex secondary-index query interface for the /query endpoint."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback

  @example_query Jason.encode!(
                   %{
                     "query_list" => [
                       %{
                         "index_name" => "age_int",
                         "start_term" => "18",
                         "end_term" => "65"
                       }
                     ],
                     "accumulation_option" => "keys",
                     "timeout" => 60,
                     "max_results" => 100
                   },
                   pretty: true
                 )

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Query",
       active_nav: "Query",
       bucket: "users",
       type: "default",
       query_text: @example_query,
       results: nil,
       error: nil,
       running: false
     )}
  end

  @impl true
  def handle_event(
        "run_query",
        %{"bucket" => bucket, "type" => type, "query" => query_text},
        socket
      ) do
    bucket = String.trim(bucket)
    type = String.trim(type)

    socket =
      assign(socket,
        bucket: bucket,
        type: type,
        query_text: query_text,
        running: true,
        error: nil
      )

    if bucket == "" do
      {:noreply, assign(socket, running: false, error: "Bucket is required")}
    else
      {:noreply, execute_query(socket, bucket, type, query_text)}
    end
  end

  defp execute_query(socket, bucket, type, query_text) do
    case Jason.decode(query_text) do
      {:ok, query} ->
        opts = if type == "" or type == "default", do: [], else: [type: type]

        case Client.impl().run_query(Client.base_url(), bucket, query, opts) do
          {:ok, result} ->
            assign(socket, running: false, results: result, error: nil)

          {:error, reason} ->
            assign(socket,
              running: false,
              results: nil,
              error: "Query failed: #{inspect(reason)}"
            )
        end

      {:error, err} ->
        assign(socket, running: false, error: "Invalid JSON: #{Exception.message(err)}")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">Query</h1>
      </div>

      <.error_banner :if={@error} message={@error} />

      <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4 mb-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Run /query</h2>
        <form phx-submit="run_query" class="space-y-3">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <input
              type="text"
              name="bucket"
              value={@bucket}
              placeholder="Bucket"
              class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
            <input
              type="text"
              name="type"
              value={@type}
              placeholder="Type (default)"
              class="w-full rounded-lg px-3 py-2 text-sm border border-[#EEECE8] bg-white text-[#1A1A1A] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
          </div>
          <textarea
            name="query"
            rows="12"
            class="w-full rounded-lg px-3 py-2 text-sm font-mono bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            style="resize: vertical;"
          >{@query_text}</textarea>
          <div class="flex justify-end">
            <button
              type="submit"
              disabled={@running}
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            >
              {if @running, do: "Running...", else: "Run Query"}
            </button>
          </div>
        </form>
      </div>

      <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">Result</h2>
        <%= if @results do %>
          <pre class="text-sm font-mono whitespace-pre-wrap rounded-lg px-4 py-3 overflow-x-auto bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8]">{Jason.encode!(@results, pretty: true)}</pre>
        <% else %>
          <p class="text-sm text-[#8A8A8A]">Run a query to see output.</p>
        <% end %>
      </div>
    </div>
    """
  end
end

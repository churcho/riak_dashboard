defmodule RiakDashboardWeb.IndexQueryLive do
  @moduledoc "Secondary index query interface for running 2i lookups against Riak buckets."

  use RiakDashboardWeb, :live_view

  alias RiakDashboard.Cluster.Client

  import RiakDashboardWeb.Components.Dashboard.Feedback

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Index Query",
        active_nav: "Index Query",
        bucket: "",
        index_field: "",
        query_type: :exact,
        term: "",
        range_start: "",
        range_end: "",
        max_results: "",
        results: nil,
        loading: false,
        error: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_query_type", _params, socket) do
    new_type = if socket.assigns.query_type == :exact, do: :range, else: :exact
    {:noreply, assign(socket, query_type: new_type)}
  end

  def handle_event("run_query", params, socket) do
    bucket = String.trim(params["bucket"] || "")
    index_field = String.trim(params["index_field"] || "")

    case validate_query_params(bucket, index_field) do
      {:error, message} ->
        {:noreply, assign(socket, error: message)}

      :ok ->
        socket =
          socket
          |> assign(
            bucket: bucket,
            index_field: index_field,
            term: params["term"] || "",
            range_start: params["range_start"] || "",
            range_end: params["range_end"] || "",
            max_results: params["max_results"] || ""
          )
          |> run_query(bucket, index_field, params)

        {:noreply, socket}
    end
  end

  defp validate_query_params("", _index_field), do: {:error, "Bucket name is required"}
  defp validate_query_params(_bucket, ""), do: {:error, "Index field is required"}
  defp validate_query_params(_bucket, _index_field), do: :ok

  defp run_query(socket, bucket, index_field, params) do
    socket = assign(socket, loading: true, error: nil)
    client = Client.impl()
    base_url = Client.base_url()

    term_or_range =
      if socket.assigns.query_type == :exact do
        String.trim(params["term"] || "")
      else
        {String.trim(params["range_start"] || ""), String.trim(params["range_end"] || "")}
      end

    max_results = parse_max_results(params["max_results"] || "")
    opts = if max_results, do: [max_results: max_results], else: []

    case client.index_query(base_url, bucket, index_field, term_or_range, opts) do
      {:ok, data} ->
        assign(socket, results: data, loading: false)

      {:error, reason} ->
        assign(socket, error: "Query failed: #{inspect(reason)}", loading: false)
    end
  end

  defp parse_max_results(""), do: nil

  defp parse_max_results(str) do
    case Integer.parse(String.trim(str)) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between flex-wrap gap-3 mb-6">
        <h1 class="text-xl sm:text-2xl font-bold text-[#1A1A1A] dark:text-[#E2E8F0]">
          Secondary Index Query
        </h1>
      </div>

      <.error_banner :if={@error} message={@error} />

      <%!-- Query Form --%>
      <div class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-4 mb-6">
        <h2 class="text-sm font-semibold mb-3 text-[#8A8A8A]">
          Query Parameters
        </h2>
        <form phx-submit="run_query" class="space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <%!-- Bucket --%>
            <div>
              <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
                Bucket
              </label>
              <input
                type="text"
                name="bucket"
                value={@bucket}
                placeholder="e.g. users"
                class="w-full px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              />
            </div>
            <%!-- Index Field --%>
            <div>
              <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
                Index Field
              </label>
              <input
                type="text"
                name="index_field"
                value={@index_field}
                placeholder="e.g. email_bin, age_int"
                class="w-full px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              />
            </div>
          </div>

          <%!-- Query Type Toggle --%>
          <div>
            <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
              Query Type
            </label>
            <div class="flex gap-2">
              <button
                type="button"
                phx-click="toggle_query_type"
                class={[
                  "px-4 py-1.5 rounded-lg text-sm font-medium cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
                  if(@query_type == :exact,
                    do: "bg-[#e77117] text-white border-none",
                    else: "bg-white text-[#1A1A1A] border border-[#EEECE8]"
                  )
                ]}
              >
                Exact Match
              </button>
              <button
                type="button"
                phx-click="toggle_query_type"
                class={[
                  "px-4 py-1.5 rounded-lg text-sm font-medium cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
                  if(@query_type == :range,
                    do: "bg-[#e77117] text-white border-none",
                    else: "bg-white text-[#1A1A1A] border border-[#EEECE8]"
                  )
                ]}
              >
                Range
              </button>
            </div>
          </div>

          <%!-- Exact Match: single term --%>
          <div :if={@query_type == :exact}>
            <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
              Term
            </label>
            <input
              type="text"
              name="term"
              value={@term}
              placeholder="e.g. user@example.com"
              class="w-full px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
          </div>

          <%!-- Range: start and end --%>
          <div :if={@query_type == :range} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
                Range Start
              </label>
              <input
                type="text"
                name="range_start"
                value={@range_start}
                placeholder="e.g. 18"
                class="w-full px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              />
            </div>
            <div>
              <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
                Range End
              </label>
              <input
                type="text"
                name="range_end"
                value={@range_end}
                placeholder="e.g. 65"
                class="w-full px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              />
            </div>
          </div>

          <%!-- Max Results --%>
          <div>
            <label class="block text-xs font-medium mb-1 text-[#8A8A8A]">
              Max Results (optional)
            </label>
            <input
              type="text"
              name="max_results"
              value={@max_results}
              placeholder="e.g. 100"
              class="w-full sm:w-48 px-3 py-2 rounded-lg text-sm bg-[#FAFAF8] text-[#1A1A1A] border border-[#EEECE8] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
            />
          </div>

          <%!-- Submit --%>
          <div>
            <button
              type="submit"
              class="px-4 py-2 rounded-lg text-sm font-medium cursor-pointer bg-[#e77117] text-white border-none focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]"
              disabled={@loading}
            >
              {if @loading, do: "Running...", else: "Run Query"}
            </button>
          </div>
        </form>
      </div>

      <%!-- Results Section --%>
      <%= if @results do %>
        <div class="mb-4">
          <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">
            Results
            <span class="text-sm font-normal text-[#8A8A8A]">
              ({length(@results["keys"] || [])} keys)
            </span>
          </h2>
        </div>

        <%= if (@results["keys"] || []) != [] do %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden">
            <table class="w-full">
              <thead>
                <tr class="bg-[#F5F3EF]">
                  <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
                    #
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
                    Key
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={{key, idx} <- Enum.with_index(@results["keys"], 1)}
                  class="border-t border-[#F0EFEB]"
                >
                  <td class="px-4 py-3 text-sm tabular-nums text-[#8A8A8A]" style="width: 60px;">
                    {idx}
                  </td>
                  <td class="px-4 py-3 font-mono text-sm text-[#1A1A1A]">
                    {key}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div
            :if={@results["continuation"]}
            class="mt-3 text-xs text-[#8A8A8A]"
          >
            More results available (continuation token present).
          </div>
        <% else %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 text-center">
            <p class="text-sm text-[#8A8A8A]">
              No matching keys found.
            </p>
          </div>
        <% end %>
      <% end %>

      <%!-- Initial empty state --%>
      <div
        :if={is_nil(@results) && !@loading}
        class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 text-center"
      >
        <p class="text-sm text-[#8A8A8A]">
          Enter query parameters above and click "Run Query" to search by secondary index.
        </p>
      </div>
    </div>
    """
  end
end

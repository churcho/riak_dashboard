defmodule RiakDashboardWeb.CrdtLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders CRDT value", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/counters/buckets/stats/datatypes/page_views")
    assert html =~ "42"
  end

  test "renders CRDT lookup/create page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/datatypes")
    assert html =~ "Open Existing CRDT"
    assert html =~ "Create New CRDT"
  end
end

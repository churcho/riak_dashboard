defmodule RiakDashboardWeb.CounterLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders counter with current value", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/buckets/users/counters/page_views")
    assert html =~ "42"
  end

  test "renders counter lookup page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/counters")
    assert html =~ "Open Counter"
  end
end

defmodule RiakDashboardWeb.QueryLiveTest do
  use RiakDashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders query page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/query")

    assert html =~ "Run /query"
    assert html =~ "Run Query"
  end
end

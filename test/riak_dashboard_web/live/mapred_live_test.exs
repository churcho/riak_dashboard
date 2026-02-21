defmodule RiakDashboardWeb.MapredLiveTest do
  use RiakDashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders MapReduce query page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/mapred")
    assert html =~ "MapReduce"
  end
end

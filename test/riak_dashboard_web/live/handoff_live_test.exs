defmodule RiakDashboardWeb.HandoffLiveTest do
  use RiakDashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders handoff page in loading state", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/handoff")
    assert html =~ "Handoff Transfers"
    assert html =~ "Loading handoff data..."
  end
end

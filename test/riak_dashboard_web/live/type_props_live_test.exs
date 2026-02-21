defmodule RiakDashboardWeb.TypePropsLiveTest do
  use RiakDashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders type listing page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types")
    assert html =~ "Type Properties"
    assert html =~ "default"
  end

  test "renders type detail page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/default/props")
    assert html =~ "n_val"
  end
end

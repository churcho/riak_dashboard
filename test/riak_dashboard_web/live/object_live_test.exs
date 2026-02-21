defmodule RiakDashboardWeb.ObjectLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders object detail view", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/buckets/users/keys/user_001")

    assert html =~ "user_001"
    assert html =~ "application/json"
  end

  test "renders object detail for a typed bucket", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/default/buckets/users/keys/user_001")

    assert html =~ "user_001"
    assert html =~ "application/json"
  end
end

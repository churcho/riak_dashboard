defmodule RiakDashboardWeb.BucketPropsLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders bucket properties", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/buckets/users/props")
    assert html =~ "Properties"
    assert html =~ "n_val"
  end

  test "renders bucket properties for a typed bucket", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/default/buckets/users/props")
    assert html =~ "Properties"
    assert html =~ "n_val"
  end
end

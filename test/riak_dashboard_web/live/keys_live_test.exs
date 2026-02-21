defmodule RiakDashboardWeb.KeysLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders key listing for a bucket", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/buckets/users/keys")

    assert html =~ "users"
    assert html =~ "user_001"
  end

  test "renders key listing for a typed bucket", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/default/buckets/users/keys")

    assert html =~ "users"
    assert html =~ "user_001"
  end
end

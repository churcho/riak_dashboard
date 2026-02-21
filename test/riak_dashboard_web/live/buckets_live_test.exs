defmodule RiakDashboardWeb.BucketsLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders bucket listing page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/buckets")
    assert html =~ "Buckets"
    assert html =~ "users"
  end

  test "renders typed bucket listing route", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/types/default/buckets")
    assert html =~ "Buckets"
  end
end

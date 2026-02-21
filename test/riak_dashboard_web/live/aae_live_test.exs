defmodule RiakDashboardWeb.AaeLiveTest do
  use RiakDashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders AAE page in loading state", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/aae")
    assert html =~ "AAE Exchanges"
    assert html =~ "Loading AAE data..."
  end
end

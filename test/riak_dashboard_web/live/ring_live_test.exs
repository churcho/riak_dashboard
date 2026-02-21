defmodule RiakDashboardWeb.RingLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Provide basic auth credentials for test requests
  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders ring page in loading state", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/ring")

    assert html =~ "Ring Ownership"
    assert html =~ "Loading ring data..."
  end
end

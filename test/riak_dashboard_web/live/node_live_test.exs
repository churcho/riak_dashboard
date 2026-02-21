defmodule RiakDashboardWeb.NodeLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Provide basic auth credentials for test requests
  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders node detail page in loading state", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/nodes/dev1@127.0.0.1")

    assert html =~ "dev1@127.0.0.1"
    assert html =~ "Loading node stats..."
  end
end

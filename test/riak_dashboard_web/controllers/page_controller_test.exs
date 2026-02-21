defmodule RiakDashboardWeb.ClusterLiveTest do
  use RiakDashboardWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / renders the cluster overview page", %{conn: conn} do
    credentials = Base.encode64("admin:password")

    conn =
      conn
      |> put_req_header("authorization", "Basic #{credentials}")

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Cluster Overview"
    assert html =~ "Cluster"
  end
end

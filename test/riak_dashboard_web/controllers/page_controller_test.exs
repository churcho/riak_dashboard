defmodule RiakDashboardWeb.ClusterLiveTest do
  use RiakDashboardWeb.ConnCase

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    credentials = Base.encode64("admin:password")
    conn = put_req_header(conn, "authorization", "Basic #{credentials}")
    {:ok, conn: conn}
  end

  test "GET / renders the cluster overview page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Cluster"
    assert html =~ "Nodes"
  end

  test "select_range with invalid value does not crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    html = render_click(view, "select_range", %{"range" => "garbage"})
    assert html =~ "Cluster"
  end

  test "select_metric with unknown key does not crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    html = render_click(view, "select_metric", %{"metric" => "nonexistent"})
    assert html =~ "Cluster"
  end

  test "select_node with unknown node does not crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    html = render_click(view, "select_node", %{"node" => "unknown@node"})
    assert html =~ "Cluster"
  end
end

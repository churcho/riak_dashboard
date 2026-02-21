defmodule RiakDashboardWeb.IndexQueryLiveTest do
  use RiakDashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @auth_header "Basic " <> Base.encode64("admin:password")

  test "renders index query page", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, _view, html} = live(conn, "/query/index")
    assert html =~ "Secondary Index Query"
  end

  test "runs an exact match query and displays results", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, view, _html} = live(conn, "/query/index")

    html =
      view
      |> form("form", %{
        "bucket" => "users",
        "index_field" => "email_bin",
        "term" => "test@example.com"
      })
      |> render_submit()

    assert html =~ "user_001"
    assert html =~ "user_002"
    assert html =~ "user_003"
  end

  test "toggles between exact and range query types", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, view, html} = live(conn, "/query/index")

    # Starts in exact mode
    assert html =~ "Term"

    # Toggle to range
    html = render_click(view, "toggle_query_type")
    assert html =~ "Range Start"
    assert html =~ "Range End"

    # Toggle back to exact
    html = render_click(view, "toggle_query_type")
    assert html =~ "Term"
  end

  test "shows validation error when bucket is empty", %{conn: conn} do
    conn = put_req_header(conn, "authorization", @auth_header)
    {:ok, view, _html} = live(conn, "/query/index")

    html =
      view
      |> form("form", %{"bucket" => "", "index_field" => "email_bin", "term" => "x"})
      |> render_submit()

    assert html =~ "Bucket name is required"
  end
end

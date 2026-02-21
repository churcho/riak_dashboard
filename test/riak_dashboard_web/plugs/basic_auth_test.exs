defmodule RiakDashboardWeb.Plugs.BasicAuthTest do
  use RiakDashboardWeb.ConnCase, async: true

  describe "BasicAuth plug" do
    test "returns 401 without credentials", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") == [~s(Basic realm="Riak Dashboard")]
    end

    test "returns 200 with valid credentials", %{conn: conn} do
      credentials = Base.encode64("admin:password")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> get(~p"/")

      assert conn.status == 200
    end

    test "returns 401 with wrong credentials", %{conn: conn} do
      credentials = Base.encode64("wrong:creds")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> get(~p"/")

      assert conn.status == 401
    end
  end
end

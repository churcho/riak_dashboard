defmodule RiakDashboardWeb.Plugs.BasicAuth do
  @moduledoc "HTTP Basic Auth plug with config-driven credentials."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:riak_dashboard, :basic_auth, [])
    expected_user = Keyword.get(config, :username, "admin")
    expected_pass = Keyword.get(config, :password, "password")

    with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         [^expected_user, ^expected_pass] <- String.split(decoded, ":", parts: 2) do
      conn
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="Riak Dashboard"))
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end

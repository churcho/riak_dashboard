defmodule RiakDashboardWeb.Router do
  use RiakDashboardWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {RiakDashboardWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(RiakDashboardWeb.Plugs.BasicAuth)
  end

  scope "/", RiakDashboardWeb do
    pipe_through([:browser, :auth])

    live("/", ClusterLive, :index)
    live("/nodes", ClusterLive, :index)
    live("/ring", RingLive, :index)
    live("/nodes/:node", NodeLive, :show)
    live("/handoff", HandoffLive, :index)
    live("/aae", AaeLive, :index)
    live("/buckets", BucketsLive, :index)
    live("/types/:type/buckets", BucketsLive, :index)
    live("/buckets/:bucket/keys", KeysLive, :index)
    live("/buckets/:bucket/keys/:key", ObjectLive, :show)
    live("/buckets/:bucket/props", BucketPropsLive, :show)
    live("/types/:type/buckets/:bucket/keys", KeysLive, :index)
    live("/types/:type/buckets/:bucket/keys/:key", ObjectLive, :show)
    live("/types/:type/buckets/:bucket/props", BucketPropsLive, :show)
    live("/buckets/:bucket/counters/:key", CounterLive, :show)
    live("/counters", CounterLive, :index)
    live("/types/:type/buckets/:bucket/datatypes/:key", CrdtLive, :show)
    live("/datatypes", CrdtLive, :index)
    live("/mapred", MapredLive, :index)
    live("/query", QueryLive, :index)
    live("/query/index", IndexQueryLive, :index)
    live("/types", TypePropsLive, :index)
    live("/types/:type/props", TypePropsLive, :show)
  end

  # Other scopes may use custom stacks.
  # scope "/api", RiakDashboardWeb do
  #   pipe_through :api
  # end
end

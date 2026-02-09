defmodule IsupayxWeb.Router do
  use IsupayxWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Pipeline for authenticated transactions API
  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug IsupayxWeb.Plugs.AuthenticateMerchant
    plug IsupayxWeb.Plugs.IdempotencyCheck
  end

  scope "/api/v1", IsupayxWeb do
    pipe_through :authenticated_api

    post "/transactions", TransactionController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:isupayx, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: IsupayxWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

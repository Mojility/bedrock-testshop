defmodule BusinessWeb.Router do
  use BusinessWeb, :router

  import BusinessWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BusinessWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'self'"
    }

    plug :fetch_current_scope_for_user
    plug BusinessWeb.Plugs.Exploration
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BusinessWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/leads", LeadController, :create
    get "/media/:id/:variant", MediaController, :show
  end

  scope "/health", BusinessWeb do
    pipe_through :api
    get "/ready", HealthController, :ready
  end

  # Machine-authenticated rendering uses no browser session or customer login.
  scope "/api/website", BusinessWeb do
    pipe_through :api
    post "/preview", WebsitePreviewController, :render_scene
  end

  # Other scopes may use custom stacks.
  # scope "/api", BusinessWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:business, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BusinessWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BusinessWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{BusinessWeb.UserAuth, :require_authenticated}] do
      live "/app/leads", LeadsLive, :index
      live "/app/team", TeamLive, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end
  end

  scope "/", BusinessWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{BusinessWeb.UserAuth, :mount_current_scope}] do
      if Application.compile_env(:business, :dev_routes) do
        live "/dev/catalogue", CatalogueLive, :index
        live "/dev/catalogue/:section", CatalogueLive, :index
      end

      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end

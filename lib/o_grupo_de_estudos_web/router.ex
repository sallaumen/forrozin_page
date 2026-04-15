defmodule OGrupoDeEstudosWeb.Router do
  use OGrupoDeEstudosWeb, :router

  @compile {:no_warn_undefined, Plug.Swoosh.MailboxPreview}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OGrupoDeEstudosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OGrupoDeEstudosWeb.UserAuth, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :redirect_if_authenticated do
    plug OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated
  end

  scope "/", OGrupoDeEstudosWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    live "/signup", UserRegistrationLive
  end

  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    live "/", LandingLive
    delete "/logout", UserSessionController, :delete
    get "/confirm/:token", UserConfirmationController, :confirm
    get "/auto-login/:user_id", UserSessionController, :auto_login
  end

  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    live "/collection", CollectionLive
    live "/community", CommunityLive
    live "/graph", GraphLive
    live "/graph/visual", GraphVisualLive
    live "/steps/:code", StepLive
    live "/users/:username", UserProfileLive
    live "/settings", SettingsLive
    live "/admin/links", AdminLinksLive
    live "/admin/backups", AdminBackupsLive
    get "/admin/backups/download/:filename", BackupController, :download
  end

  if Application.compile_env(:o_grupo_de_estudos, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OGrupoDeEstudosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

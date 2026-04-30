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
    plug OGrupoDeEstudosWeb.Plugs.DeviceTracker
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check — no SSL redirect, no auth, just 200 OK
  scope "/healthz" do
    get "/", OGrupoDeEstudosWeb.HealthController, :check
  end

  # Sitemap — public, no auth
  scope "/" do
    get "/sitemap.xml", OGrupoDeEstudosWeb.SitemapController, :index
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
    live "/about", AboutLive
    live "/forgot-password", ForgotPasswordLive
    live "/reset-password/:token", ResetPasswordLive
    delete "/logout", UserSessionController, :delete
    get "/confirm/:token", UserConfirmationController, :confirm
    get "/auto-login/:token", UserSessionController, :auto_login
  end

  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    live "/collection", CollectionLive
    live "/sequence", SequenceLive
    live "/notifications", NotificationsLive
    live "/graph", GraphLive
    live "/graph/visual", GraphVisualLive
    live "/study", StudyLive
    live "/study/shared/:id", StudySharedLive
    live "/study/invite/:slug", StudyInviteLive
    live "/steps/:code", StepLive
    live "/users/:username", UserProfileLive
    live "/settings", SettingsLive
    live "/admin/links", AdminLinksLive
    live "/admin/backups", AdminBackupsLive
    live "/admin/suggestions", AdminSuggestionsLive
    live "/admin/errors", AdminErrorsLive
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

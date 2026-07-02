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
    plug OGrupoDeEstudosWeb.Plugs.ContentSecurityPolicy
    plug OGrupoDeEstudosWeb.UserAuth, :fetch_current_user
    plug OGrupoDeEstudosWeb.Plugs.DeviceTracker
    plug OGrupoDeEstudosWeb.Plugs.TrackDailyActivity
  end

  pipeline :require_admin do
    plug OGrupoDeEstudosWeb.UserAuth, :require_admin
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

  # Autenticação — redireciona para /collection se já logado
  scope "/", OGrupoDeEstudosWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create

    live_session :redirect_if_authenticated,
      on_mount: [{OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated}] do
      live "/signup", UserRegistrationLive
    end
  end

  # Rotas públicas — current_user é opcional (carregado, sem redirecionar)
  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    delete "/logout", UserSessionController, :delete
    get "/confirm/:token", UserConfirmationController, :confirm
    get "/auto-login/:token", UserSessionController, :auto_login

    live_session :public, on_mount: [{OGrupoDeEstudosWeb.UserAuth, :mount_current_user}] do
      live "/", LandingLive
      live "/about", AboutLive
      live "/forgot-password", ForgotPasswordLive
      live "/reset-password/:token", ResetPasswordLive
      live "/study/invite/:slug", StudyInviteLive
    end
  end

  # Rotas que exigem autenticação e/ou papel admin (gating no router via live_session)
  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}] do
      live "/collection", CollectionLive
      live "/sequence", SequenceLive
      live "/notifications", NotificationsLive
      live "/graph/visual", GraphVisualLive
      live "/study", StudyLive
      live "/study/shared/:id", StudySharedLive
      live "/steps/:code", StepLive
      live "/users/:username", UserProfileLive
      live "/settings", SettingsLive
    end

    live_session :admin, on_mount: [{OGrupoDeEstudosWeb.UserAuth, :ensure_admin}] do
      live "/graph", GraphLive
      live "/admin/links", AdminLinksLive
      live "/admin/backups", AdminBackupsLive
      live "/admin/suggestions", AdminSuggestionsLive
      live "/admin/errors", AdminErrorsLive
    end
  end

  # Rotas admin de conn (controller/dashboard): o gate e o plug require_admin,
  # ja que on_mount de live_session nao cobre requests HTTP comuns.
  scope "/admin", OGrupoDeEstudosWeb do
    pipe_through [:browser, :require_admin]

    get "/backups/download/:filename", BackupController, :download
  end

  import Phoenix.LiveDashboard.Router

  scope "/admin" do
    pipe_through [:browser, :require_admin]

    live_dashboard "/dashboard",
      metrics: OGrupoDeEstudosWeb.Telemetry,
      ecto_repos: [OGrupoDeEstudos.Repo],
      csp_nonce_assign_key: :csp_nonce,
      live_session_name: :admin_live_dashboard
  end

  if Application.compile_env(:o_grupo_de_estudos, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    # LiveDashboard relies on inline scripts/eval; keep it off the strict CSP
    # pipeline. Dev-only, so this never reaches production.
    pipeline :dev_browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :put_root_layout, html: {OGrupoDeEstudosWeb.Layouts, :root}
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    scope "/dev" do
      pipe_through :dev_browser

      live_dashboard "/dashboard", metrics: OGrupoDeEstudosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

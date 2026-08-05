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

  # Health check: no SSL redirect, no auth, just 200 OK.
  scope "/healthz" do
    get "/", OGrupoDeEstudosWeb.HealthController, :check
  end

  scope "/" do
    get "/sitemap.xml", OGrupoDeEstudosWeb.SitemapController, :index
  end

  pipeline :redirect_if_authenticated do
    plug OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated
  end

  # Redirects to /collection when already logged in.
  scope "/", OGrupoDeEstudosWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    get "/auth/google", GoogleAuthController, :request
    get "/auth/google/callback", GoogleAuthController, :callback

    live_session :redirect_if_authenticated,
      on_mount: [{OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated}] do
      live "/signup", UserRegistrationLive
    end
  end

  # Public routes: current_user is optional, loaded without redirecting.
  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    # Workshop media goes through the session on purpose, since the file is
    # restricted. The video poster has the same lock: it is a frame of paid content.
    get "/workshop-media/:id", WorkshopMediaController, :show
    get "/workshop-media/:id/poster", WorkshopMediaController, :poster

    # A receipt is stricter than the gallery: only whoever sent it and whoever
    # runs the class get past the controller.
    get "/workshop-receipts/:id", ReceiptController, :workshop
    get "/program-receipts/:id", ReceiptController, :program

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

  # A workshop is shared by link (WhatsApp), so the page opens for whoever has no
  # account yet. What is private (conversation, enrolled names, management) stays
  # behind login inside the LiveView itself.
  scope "/", OGrupoDeEstudosWeb do
    pipe_through :browser

    live_session :workshops_public,
      on_mount: [{OGrupoDeEstudosWeb.UserAuth, :mount_current_user}] do
      live "/workshops/:slug", WorkshopLive
      live "/programs/:slug", WorkshopProgramLive
    end

    # The image the link preview points at. Beside the pages it describes, and
    # outside the live_session because a crawler does not carry a session.
    get "/workshops/:slug/og-image", OgImageController, :workshop
    get "/programs/:slug/og-image", OgImageController, :program
  end

  # Routes that require authentication or the admin role, gated by live_session.
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
      live "/study/workshops", WorkshopsLive
      live "/study/workshops/new", WorkshopFormLive, :new
      live "/study/workshops/:slug/edit", WorkshopFormLive, :edit
      live "/study/programs/new", WorkshopProgramFormLive, :new
      live "/study/programs/:slug/edit", WorkshopProgramFormLive, :edit
      live "/workshops/:slug/manage", WorkshopManageLive
    end

    live_session :admin, on_mount: [{OGrupoDeEstudosWeb.UserAuth, :ensure_admin}] do
      live "/graph", GraphLive
      live "/admin/links", AdminLinksLive
      live "/admin/backups", AdminBackupsLive
      live "/admin/suggestions", AdminSuggestionsLive
      live "/admin/errors", AdminErrorsLive
    end
  end

  # Admin conn routes (controller/dashboard): the gate is the require_admin plug,
  # since a live_session on_mount does not cover plain HTTP requests.
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

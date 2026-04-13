defmodule ForrozinWeb.Router do
  use ForrozinWeb, :router

  # Plug.Swoosh.MailboxPreview é carregado condicionalmente em Swoosh
  @compile {:no_warn_undefined, Plug.Swoosh.MailboxPreview}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ForrozinWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ForrozinWeb.UserAuth, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :redirect_if_authenticated do
    plug ForrozinWeb.UserAuth, :redirect_if_authenticated
  end

  # Rotas acessíveis apenas para não-autenticados
  scope "/", ForrozinWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/entrar", UserSessionController, :new
    post "/entrar", UserSessionController, :create
    live "/cadastro", UserRegistrationLive
  end

  # Rotas públicas (autenticado ou não)
  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/", LandingLive
    delete "/sair", UserSessionController, :delete
    get "/confirmar/:token", UserConfirmationController, :confirm
  end

  # Rotas da enciclopédia (autenticação verificada no próprio LiveView)
  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/acervo", AcervoLive
    live "/grafo", GrafoLive
    live "/grafo/visual", GrafoVisualLive
    live "/passos/:codigo", PassoLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ForrozinWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:forrozin, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ForrozinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

defmodule ForrozinWeb.Router do
  use ForrozinWeb, :router

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

  scope "/", ForrozinWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    live "/signup", UserRegistrationLive
  end

  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/", LandingLive
    delete "/logout", UserSessionController, :delete
    get "/confirm/:token", UserConfirmationController, :confirm
  end

  scope "/", ForrozinWeb do
    pipe_through :browser

    live "/collection", CollectionLive
    live "/graph", GraphLive
    live "/graph/visual", GraphVisualLive
    live "/steps/:code", StepLive
  end

  if Application.compile_env(:forrozin, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ForrozinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

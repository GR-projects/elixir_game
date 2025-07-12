defmodule Web.Router do
  use Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :ensure_authorized
  end

  pipeline :unauth do
    plug :ensure_unauthorized
  end

  defp ensure_authorized(conn, _opts) do
    case get_session(conn, :user) do
      nil ->
        redirect(conn, to: "/login")

      user ->
        conn
        |> assign(:user, user)
    end
  end

  defp ensure_unauthorized(conn, _opts) do
    case get_session(conn, :user) do
      nil ->
        conn

      user ->
        conn
        |> assign(:user, user)
        |> redirect(to: "/")
    end
  end

  # here we can have additional scope, just for authenticated users, like in example:
  # pipeline :auth do
  #   plug :ensure_authenticated
  # end

  # scope "/" do
  #   pipe_through [:browser, :auth]

  #   get "/posts/new", PostController, :new
  #   post "/posts", PostController, :create
  # end
  scope "/", Web do
    pipe_through [:browser, :auth]
    get "/showMe", AuthController, :show
    get "/", PageController, :main
    get "/equipment", PageController, :equipment
    post "/logout", AuthController, :logout
    resources "/character", CharacterController
  end

  scope "/", Web do
    pipe_through [:browser, :unauth]
    post "/register", AuthController, :register
    get "/register", AuthController, :register_page
    get "/login", AuthController, :login_page
    post "/login", AuthController, :login
  end

  # Other scopes may use custom stacks.
  # scope "/api", Web do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

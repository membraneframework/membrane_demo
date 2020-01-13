defmodule Example.Auth.Router do
  use Plug.Router
  require EEx
  alias Example.Auth.UserManager
  alias Example.Auth.UserManager.Guardian

  plug(Plug.Static,
    at: "/",
    from: :example_auth
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_file(conn, 200, "priv/static/html/login.html")
  end

  get "/videochat" do
    send_file(conn, 200, "priv/static/html/videochat.html")
  end

  post "/login" do
    {:ok, body, conn} = read_body(conn)

    case URI.decode_query(body) do
      %{"username" => username, "password" => password} ->
        UserManager.authenticate_user(username, password)
        |> login_result(conn)

      _ ->
        send_resp(conn, 500, "Could not decode login query")
    end
  end

  post "/logout" do
    conn
    |> Guardian.Plug.sign_out()
    |> Guardian.Plug.clear_remember_me()
    |> redirect("/")
  end

  match _ do
    send_resp(conn, 404, "404")
  end

  defp login_result({:error, _error}, conn) do
    redirect(conn, "/")
  end

  defp login_result({:ok, user}, conn) do
    conn
    |> Guardian.Plug.sign_in(user)
    |> Guardian.Plug.remember_me(user)
    |> redirect("/videochat")
  end

  defp redirect(conn, to) do
    conn
    |> put_resp_header("location", to)
    |> send_resp(conn.status || 302, "text/html")
  end
end

defmodule Web.Api.SessionController do
  use Web, :controller

  alias Web.Plugs.SessionTimeout

  plug :fetch_session when action in [:check_session_timeout]

  # Might be able to just call SessionTimeout plug
  def check_session_timeout(conn, opts) do
    timeout_at = get_session(conn, :session_timeout_at)
    timeout_after_minutes = opts[:timeout_after_minutes] || SessionTimeout.timeout_interval()
    new_timeout = new_session_timeout_at(timeout_after_minutes)

    if timeout_at && now() > timeout_at do
      logout_user(conn)
    else
      conn
      |> put_session(:session_timeout_at, new_timeout)
      |> assign(:new_timeout, new_timeout)
      |> render("success.json")
    end
  end

  defp logout_user(conn) do
    conn
    |> clear_session()
    |> configure_session([:renew])
    |> assign(:session_timeout, true)
    |> redirect(to: Routes.session_path(conn, :new))
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  defp new_session_timeout_at(timeout_after_minutes) do
    now() + timeout_after_minutes * 60
  end
end
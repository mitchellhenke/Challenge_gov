defmodule Web.Plugs.SessionTimeout do
  @moduledoc """
  Manage session timeout
  """
  alias Web.SessionController

  def init(opts \\ []) do
    Keyword.merge([timeout_after_minutes: timeout_interval()], opts)
  end

  def call(conn, opts) do
    SessionController.check_last_active(conn)
    SessionController.check_session_timeout(conn, opts)
  end

  # TODO: Handle session timeout defaults and parsing better
  def timeout_interval do
    with timeout_var <- Application.get_env(:challenge_gov, :session_timeout_in_minutes),
         false <- is_nil(timeout_var),
         false <- is_integer(timeout_var),
         {timeout, _} <- Integer.parse(timeout_var) do
      timeout
    else
      _ ->
        15
    end
  end
end

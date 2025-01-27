defmodule ChallengeGov.CertificationLogs do
  @moduledoc """
  Context for adding events to certification log
  """

  import Ecto.Query

  alias ChallengeGov.Accounts
  alias ChallengeGov.CertificationLogs.CertificationLog
  alias ChallengeGov.Repo
  alias ChallengeGov.Security

  require Logger

  def track(params) do
    %CertificationLog{}
    |> CertificationLog.changeset(params)
    |> Repo.insert()
  end

  def certify_user_with_approver(user, approver, approver_remote_ip) do
    track(%{
      approver_id: approver.id,
      approver_role: approver.role,
      approver_identifier: approver.email,
      approver_remote_ip: approver_remote_ip,
      user_id: user.id,
      user_role: user.role,
      user_identifier: user.email,
      certified_at: Timex.now(),
      expires_at: calulate_expiry()
    })
  end

  def certification_request(conn, user) do
    track(%{
      user_id: user.id,
      user_role: user.role,
      user_identifier: user.email,
      user_remote_ip: Security.extract_remote_ip(conn),
      requested_at: Timex.now()
    })
  end

  def check_for_expired_certifications do
    two_days_ago = Timex.shift(Timex.now(), days: -2)

    # get records where user is not decertified and expiry is past now
    results =
      CertificationLog
      |> join(:left, [r], user in assoc(r, :user))
      |> where(
        [r, user],
        r.user_id == user.id and
          user.status != "decertified" and
          user.role != "solver"
      )
      |> where([r], is_nil(r.requested_at))
      |> where([r], r.updated_at > ^two_days_ago)
      |> order_by([r], desc: r.updated_at)
      |> Repo.all()

    # filter to most recent result per user
    unique_results_by_user = Enum.uniq_by(results, fn x -> x.user_id end)

    # decertify found users
    Enum.map(unique_results_by_user, fn r ->
      if Timex.to_unix(r.expires_at) < Timex.to_unix(Timex.now()) do
        with {:ok, user} <- Accounts.get(r.user_id) do
          Accounts.decertify(user)
        end
      end
    end)
  end

  @doc """
  Get most current certification record by user id
  """
  def get_current_certification(%{role: "solver"}), do: {:ok, %{}}

  def get_current_certification(%{status: "pending"}), do: {:ok, %{}}

  def get_current_certification(user) do
    CertificationLog
    |> where([r], r.user_id == ^user.id)
    |> where([r], is_nil(r.requested_at))
    |> order_by([r], desc: r.expires_at)
    |> limit(1)
    |> Repo.all()
    |> List.first()
    |> return_current_certification_log()
  end

  def check_user_certification_history(%{role: "solver"}), do: {:ok, %{}}

  def check_user_certification_history(user) do
    CertificationLog
    |> where([r], r.user_id == ^user.id)
    |> order_by([r], desc: r.expires_at)
    |> limit(1)
    |> Repo.all()
    |> List.first()
    |> return_current_certification_log()
  end

  defp return_current_certification_log(nil), do: {:error, :no_log_found}
  defp return_current_certification_log(result), do: {:ok, result}

  @doc """
  calculate certification expiry based on decertification env var
  """
  def calulate_expiry do
    decertification_interval = Security.decertify_days()
    expiry = Timex.shift(DateTime.utc_now(), days: decertification_interval)
    DateTime.truncate(expiry, :second)
  end

  @doc """
  Stream certification log for CSV download
  """
  def stream_all_records do
    CertificationLog
    |> order_by([r], asc: r.id)
    |> Repo.all()
  end

  @doc """
  Filter security log for CSV download
  """
  def filter_by_params(params) do
    %{"year" => year} = params

    {datetime_start, datetime_end} = range_from(String.to_integer(year))

    CertificationLog
    |> where([r], r.certified_at >= ^datetime_start)
    |> where([r], r.certified_at <= ^datetime_end)
    |> order_by([r], asc: r.id)
    |> Repo.all()
  end

  defp range_from(year) do
    datetime_start =
      year
      |> Timex.beginning_of_year()
      |> Timex.to_datetime()

    datetime_end =
      year
      |> Timex.end_of_year()
      |> Timex.to_datetime()
      |> Timex.end_of_day()
      |> Timex.to_datetime()

    {datetime_start, datetime_end}
  end
end

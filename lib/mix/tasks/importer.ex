defmodule Mix.Tasks.ClosedChallengeImporter do
  @moduledoc """
  Importer for archived challenges
  """
  use Mix.Task
  alias ChallengeGov.Agencies
  alias ChallengeGov.Challenges
  alias ChallengeGov.HTTPClient

  def run(_file) do
    Mix.Task.run("app.start")

    result =
      File.read!(
        "lib/mix/tasks/sample_data/feed-closed-parsed_excerpt.json"
      )
    case Jason.decode(result) do
      {:ok, challenge} ->
        create_challenge(challenge)

      {:error, error} ->
        IO.inspect error
    end
  end

  @doc """
  Create a challenge based off mapped fields
  """
  def create_challenge(json) do
    result =
      Challenges.create(%{
        "user_id" => 0,
        "status" => "closed",
        "challenge_manager" => json["challenge-manager,"],
        "challenge_manager_email" => json["challenge-manager-email"],
        "poc_email" => json["point-of-contact"],
        "agency_id" => match_agency(json["agency"], json["agency-logo"]),
        "external_logo" => json["card-image"],
        "federal_partners" => match_federal_partners(json["partner-agencies-federal"]),
        "non_federal_partners" => match_non_federal_partners(json["partners-non-federal"]),
        "title" => json["challenge-title"],
        "external_url" => json["external-url"],
        "tagline" => json["tagline"],
        "description" => json["description"],
        "how_to_enter" => json["how-to-enter"],
        "fiscal_year" => json["fiscal-year"],
        "start_date" => sanitize_date(json["submission-start"]),
        "end_date" => sanitize_date(json["submission-end"]),
        "judging_criteria" => json["judging"],
        "prize_total" => sanitize_prize_amount(json["total-prize-offered-cash"]),
        "non_monetary_prizes" => json["prizes"],
        "rules" => json["rules"],
        "legal_authority" => json["legal-authority"],
        "types" => format_types(json["type-of-challenge"])
      })

    case result do
      {:ok, result} ->
        result

      {:error, error} ->
        error
    end
  end

  defp match_agency(name, logo \\ nil) do
    case Agencies.get_by_name(name) do
      {:ok, agency} ->
        agency.id

      {:error, :not_found} ->
        fuzzy_match_agency(name, logo)
    end
  end

  defp fuzzy_match_agency(name, logo \\ nil) do
    agencies = Agencies.all_for_select

    match = Enum.find(agencies, fn x ->
      String.jaro_distance(x.name, name) >= 0.9
    end)

    if !is_nil(match) do
      match.id

    else
      create_new_agency(name, logo)
    end
  end

  defp create_new_agency(name, logo) when is_nil(logo) do
    Agencies.create(:saved_to_file, %{
      "name" => "#{name}"
      })
  end

  defp create_new_agency(name, logo_url) do
    filename = Path.basename(logo_url)
    extension = Path.extname(filename)

    {:ok, tmp_file} = Stein.Storage.Temp.create(extname: extension)

    response = Finch.request(HTTPClient, :get, "https://www.challenge.gov/assets/netlify-uploads/#{filename}")

    case response do
      {:ok, %{status: 200, body: body}} ->
        File.write!(tmp_file, body, [:binary])

        Agencies.create(:saved_to_file, %{avatar: %{path: tmp_file}, name: name})

      _ ->
        Agencies.create(:saved_to_file, %{name: name})
    end
  end

  defp match_federal_partners(""), do: ""

  defp match_federal_partners(partners) do
    partner_list = String.split(partners, ",")
    Enum.map(partner_list, fn x ->
      match_agency(String.trim(x))
      |> to_string()
    end)
  end

  defp match_non_federal_partners(""), do: ""

  defp match_non_federal_partners(partners) do
    partner_list = String.split(partners, ",")

    partner_list
    |> Stream.with_index
    |> Enum.reduce(%{}, fn({partner, idx}, acc) ->
      Map.put(acc, to_string(idx), %{"name" => String.trim(partner)})
     end)
  end

  defp sanitize_date(""), do: ""

  defp sanitize_date(date) do
    with {:ok, parsed_date} <- Timex.parse(date, "{0M}/{0D}/{YYYY} {h12}:{m} {AM}") do
      {:ok, utc_date} = DateTime.from_naive(parsed_date, "Etc/UTC")
      utc_date
    end
  end

  defp sanitize_prize_amount(""), do: ""

  defp sanitize_prize_amount(prize) do
    {number, _float} =
      prize
      |> String.replace(~r"(?=.*)\,(?=.*)", "")
      |> String.replace(~r"(?=.*)\$(?=.*)", "")
      |> Integer.parse()

    number
  end

  defp format_types(""), do: ""

  defp format_types(types) do
    String.split(types, ";")
    |> Enum.map(fn x -> String.trim(x)end)
  end
end

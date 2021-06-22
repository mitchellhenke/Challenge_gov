defmodule ChallengeGov.Winners do
  @moduledoc """
  Context for winners
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Stein.Storage
  alias ChallengeGov.Repo

  alias ChallengeGov.PhaseWinners.Winner

  def get(id) do
    Winner
    |> Repo.get(id)
    |> case do
      nil ->
        {:error, :no_winner}

      winner ->
        {:ok, winner}
    end
  end

  def delete(winner) do
    Ecto.Multi.new()
    |> Multi.run(:remove_image, fn _repo, _changes ->
      remove_image(winner)
    end)
    |> Multi.delete(:delete, fn %{remove_image: winner} ->
      winner
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete: winner}} ->
        {:ok, winner}

      {:error, _, _, _} ->
        {:error, :something_went_wrong}
    end
  end

  # Uploads
  def image_path(phase_winner, key, extension),
    do: "/phase_winners/#{phase_winner.id}/winner_image_#{key}#{extension}"

  def upload_image(phase_winner, image) do
    file = Storage.prep_file(image)
    key = UUID.uuid4()
    path = image_path(phase_winner, key, file.extension)
    meta = [{:content_disposition, ~s{attachment; filename="#{file.filename}"}}]

    case Storage.upload(file, path, meta: meta) do
      :ok ->
        {:ok, path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def remove_image(winner) do
    case Storage.delete(winner.image_path) do
      :ok ->
        winner
        |> Winner.image_changeset(nil)
        |> Repo.update()

      {:error, _reason} ->
        winner
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:image, "There was an issue removing this image")
        |> Repo.update()
    end
  end
end

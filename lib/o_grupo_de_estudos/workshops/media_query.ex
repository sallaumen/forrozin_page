defmodule OGrupoDeEstudos.Workshops.MediaQuery do
  @moduledoc """
  Leituras de `WorkshopMedia`.

  A ordem é fixa: oficial primeiro, depois a comunidade, cada bloco do mais
  recente ao mais antigo. É o que o dono do produto pediu, e é o que faz o
  vídeo do professor ser a primeira coisa que a pessoa vê.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WorkshopMedia

  @doc "Mídia visível do workshop, oficial primeiro."
  @spec list_for_workshop(Ecto.UUID.t()) :: [WorkshopMedia.t()]
  def list_for_workshop(workshop_id) do
    from(m in WorkshopMedia,
      where: m.workshop_id == ^workshop_id and is_nil(m.deleted_at),
      order_by: [desc: m.official, desc: m.inserted_at],
      preload: [:uploaded_by]
    )
    |> Repo.all()
  end

  @doc "Uma mídia com escopo no workshop: id forjado de outro não encontra nada."
  @spec get_scoped(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopMedia.t() | nil
  def get_scoped(media_id, workshop_id) do
    case Ecto.UUID.cast(media_id) do
      {:ok, uuid} ->
        from(m in WorkshopMedia,
          where: m.id == ^uuid and m.workshop_id == ^workshop_id and is_nil(m.deleted_at)
        )
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Mídia por id, sem escopo. Para o controller que serve o arquivo."
  @spec get(Ecto.UUID.t()) :: WorkshopMedia.t() | nil
  def get(media_id) do
    case Ecto.UUID.cast(media_id) do
      {:ok, uuid} -> Repo.get(WorkshopMedia, uuid)
      :error -> nil
    end
  end

  @doc "Quantos arquivos e quantos bytes o workshop já guarda."
  @spec usage(Ecto.UUID.t()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
  def usage(workshop_id) do
    from(m in WorkshopMedia,
      where: m.workshop_id == ^workshop_id and is_nil(m.deleted_at),
      select: %{count: count(m.id), bytes: coalesce(sum(m.byte_size), 0)}
    )
    |> Repo.one()
  end
end

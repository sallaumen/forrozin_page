defmodule OGrupoDeEstudos.Workshops.WorkshopMedia do
  @moduledoc """
  Foto ou vídeo da galeria de um workshop.

  `storage_key` é opaco e mora fora da pasta pública: mídia de workshop pago é
  restrita a quem se inscreveu, então é servida por controller que confere
  permissão, nunca pelo `Plug.Static`.

  `official` marca o que veio de quem administra o workshop, e não de
  `User.role == :admin`: oficial aqui é "de quem dá a aula".

  `status` existe por causa do vídeo: o upload responde na hora e o transcode
  roda depois, numa fila à parte. Foto nasce `:ready`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_media" do
    field :kind, Ecto.Enum, values: [:photo, :video]
    field :storage_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :poster_key, :string
    field :status, Ecto.Enum, values: [:processing, :ready], default: :ready
    field :official, :boolean, default: false
    field :caption, :string
    field :deleted_at, :utc_datetime

    belongs_to :workshop, Workshop
    belongs_to :uploaded_by, User

    timestamps(type: :utc_datetime_usec)
  end

  @castable [
    :workshop_id,
    :uploaded_by_id,
    :kind,
    :storage_key,
    :content_type,
    :byte_size,
    :poster_key,
    :status,
    :official,
    :caption
  ]

  def changeset(media, attrs) do
    media
    |> cast(attrs, @castable)
    |> update_change(:caption, &trim/1)
    |> validate_required([:workshop_id, :kind, :storage_key, :content_type, :byte_size])
    |> validate_length(:caption, max: 200)
    |> validate_number(:byte_size, greater_than: 0)
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:uploaded_by_id)
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  @doc "Extensão a partir do content type, para nomear o arquivo no storage."
  @spec extensao(String.t()) :: String.t()
  def extensao(content_type) do
    case MIME.extensions(content_type) do
      [ext | _] -> "." <> ext
      [] -> ".bin"
    end
  end

  @doc "Se é foto ou vídeo, a partir do content type."
  @spec kind_do_tipo(String.t()) :: :photo | :video | :error
  def kind_do_tipo("image/" <> _), do: :photo
  def kind_do_tipo("video/" <> _), do: :video
  def kind_do_tipo(_outro), do: :error

  @doc """
  Status com que a mídia entra na galeria.

  Vídeo espera o transcode; foto já está no formato que o navegador abre.
  """
  @spec status_inicial(:photo | :video) :: :processing | :ready
  def status_inicial(:video), do: :processing
  def status_inicial(:photo), do: :ready
end

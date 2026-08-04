defmodule OGrupoDeEstudos.Workshops.WorkshopMedia do
  @moduledoc """
  Photo or video of a workshop gallery.

  `storage_key` is opaque and lives outside the public folder: media of a paid
  workshop is restricted to whoever enrolled, so it is served by a controller that
  checks permission, never by `Plug.Static`.

  `official` marks what came from whoever administers the workshop, not from
  `User.role == :admin`: official here means "from whoever teaches".

  `status` exists because of video: the upload answers right away and the
  transcode runs afterwards, in a separate queue. A photo is born `:ready`.
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

  @doc "Extension from the content type, to name the file in the storage."
  @spec extension(String.t()) :: String.t()
  def extension(content_type) do
    case MIME.extensions(content_type) do
      [ext | _] -> "." <> ext
      [] -> ".bin"
    end
  end

  @doc "Whether it is a photo or a video, from the content type."
  @spec kind_from_content_type(String.t()) :: :photo | :video | :error
  def kind_from_content_type("image/" <> _), do: :photo
  def kind_from_content_type("video/" <> _), do: :video
  def kind_from_content_type(_other), do: :error

  @doc """
  Status the media enters the gallery with.

  A video waits for the transcode; a photo is already in a format the browser opens.
  """
  @spec status_inicial(:photo | :video) :: :processing | :ready
  def status_inicial(:video), do: :processing
  def status_inicial(:photo), do: :ready
end

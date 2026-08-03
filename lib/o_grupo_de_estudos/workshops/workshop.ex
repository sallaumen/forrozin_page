defmodule OGrupoDeEstudos.Workshops.Workshop do
  @moduledoc """
  Evento pontual organizado por qualquer usuário (workshop, aulão, roda).

  Não tem nenhuma relação com `TeacherStudentLink`: quem se inscreve num
  workshop não vira aluno de ninguém. São conceitos diferentes de propósito.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Workshops.WorkshopEnrollment

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @slug_random_bytes 4

  schema "workshops" do
    field :slug, :string
    field :title, :string
    field :description, :string
    field :location, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :price_cents, :integer
    field :payment_info, :string
    field :capacity, :integer
    field :status, Ecto.Enum, values: [:draft, :published, :cancelled], default: :draft
    field :flyer_path, :string

    belongs_to :organizer, OGrupoDeEstudos.Accounts.User
    # Zero ou uma programacao. Quem move e o contexto, nao o changeset
    # publico: entrar numa programacao exige administrar os dois lados.
    belongs_to :program, OGrupoDeEstudos.Workshops.WorkshopProgram
    has_many :enrollments, WorkshopEnrollment

    timestamps(type: :utc_datetime_usec)
  end

  @castable [
    :title,
    :description,
    :location,
    :starts_at,
    :ends_at,
    :price_cents,
    :payment_info,
    :capacity,
    :organizer_id
  ]

  def changeset(workshop, attrs) do
    workshop
    |> cast(attrs, @castable)
    |> update_change(:title, &trim/1)
    |> update_change(:description, &trim/1)
    |> update_change(:location, &trim/1)
    |> update_change(:payment_info, &trim/1)
    |> validate_required([:title, :description, :starts_at, :organizer_id])
    |> validate_length(:title, max: 140)
    |> validate_length(:description, max: 20_000)
    |> validate_length(:location, max: 200)
    |> validate_length(:payment_info, max: 200)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_number(:capacity, greater_than: 0)
    |> validate_end_after_start()
    |> put_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:organizer_id)
  end

  @doc "Grava ou tira o flyer. Caminho vem do storage, nunca do usuario."
  def flyer_changeset(workshop, flyer_path) do
    change(workshop, flyer_path: flyer_path)
  end

  @doc "Muda o estado do workshop (publicar, cancelar, voltar a rascunho)."
  def status_changeset(workshop, status) when status in [:draft, :published, :cancelled] do
    change(workshop, status: status)
  end

  @doc "true quando a lotação foi atingida. Sem capacity, nunca lota."
  @spec full?(t(), non_neg_integer()) :: boolean()
  def full?(%__MODULE__{capacity: nil}, _enrolled_count), do: false
  def full?(%__MODULE__{capacity: capacity}, enrolled_count), do: enrolled_count >= capacity

  @doc "true quando é gratuito (sem preço definido ou zero)."
  @spec free?(t()) :: boolean()
  def free?(%__MODULE__{price_cents: nil}), do: true
  def free?(%__MODULE__{price_cents: 0}), do: true
  def free?(%__MODULE__{}), do: false

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  defp validate_end_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) != :gt do
      add_error(changeset, :ends_at, "precisa ser depois do início")
    else
      changeset
    end
  end

  # Slug legível a partir do título mais um sufixo curto: o link vai para
  # grupo de WhatsApp, então precisa dizer do que se trata sem ser adivinhável
  # a ponto de alguém varrer os workshops dos outros.
  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :title)} do
      {nil, title} when is_binary(title) -> put_change(changeset, :slug, build_slug(title))
      _ -> changeset
    end
  end

  defp build_slug(title) do
    base =
      title
      |> String.normalize(:nfd)
      |> String.replace(~r/[^A-Za-z0-9\s-]/u, "")
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "-")
      |> String.slice(0, 60)
      |> String.trim("-")

    prefix = if base == "", do: "workshop", else: base
    "#{prefix}-#{random_suffix()}"
  end

  defp random_suffix do
    @slug_random_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "")
    |> String.slice(0, 6)
  end
end

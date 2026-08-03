defmodule OGrupoDeEstudos.Workshops.WorkshopProgram do
  @moduledoc """
  Programação: vários workshops sob um nome só.

  Serve para os dois tamanhos: "quinta básico, sexta avançado" e um festival
  com quinze workshops de professores diferentes. A pessoa abre um link,
  enxerga tudo organizado por dia e escolhe onde vai.

  As datas não moram aqui: são o `min`/`max` dos workshops filhos. Coluna
  desnormalizada mentiria assim que um workshop fosse remarcado.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @slug_random_bytes 4

  schema "workshop_programs" do
    field :slug, :string
    field :title, :string
    field :description, :string
    field :location, :string
    field :status, Ecto.Enum, values: [:draft, :published, :cancelled], default: :draft
    field :flyer_path, :string
    # Preco fechado do conjunto. Nulo = so avulso, cada workshop pelo seu.
    field :price_cents, :integer
    field :payment_info, :string

    belongs_to :owner, User
    has_many :workshops, Workshop, foreign_key: :program_id

    timestamps(type: :utc_datetime_usec)
  end

  @castable [:title, :description, :location, :owner_id, :price_cents, :payment_info]

  def changeset(program, attrs) do
    program
    |> cast(attrs, @castable)
    |> update_change(:title, &trim/1)
    |> update_change(:description, &trim/1)
    |> update_change(:location, &trim/1)
    |> validate_required([:title, :owner_id])
    |> validate_length(:title, max: 140)
    |> validate_length(:description, max: 20_000)
    |> validate_length(:location, max: 200)
    |> validate_length(:payment_info, max: 200)
    |> validate_number(:price_cents, greater_than: 0)
    |> put_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:owner_id)
  end

  @doc "true quando existe preço fechado para o conjunto."
  @spec pacote?(t()) :: boolean()
  def pacote?(%__MODULE__{price_cents: cents}) when is_integer(cents) and cents > 0, do: true
  def pacote?(%__MODULE__{}), do: false

  @doc "Grava ou tira o flyer. Caminho vem do storage, nunca do usuario."
  def flyer_changeset(program, flyer_path) do
    change(program, flyer_path: flyer_path)
  end

  @doc "Muda o estado (publicar, cancelar, voltar a rascunho)."
  def status_changeset(program, status) when status in [:draft, :published, :cancelled] do
    change(program, status: status)
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  # Mesmo formato do Workshop: legivel mais um sufixo curto, porque o link vai
  # para grupo de WhatsApp e nao pode ser adivinhavel.
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

    prefix = if base == "", do: "programacao", else: base
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

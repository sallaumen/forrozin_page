defmodule OGrupoDeEstudos.Workshops.WorkshopProgram do
  @moduledoc """
  Program: several workshops under one name.

  It serves both sizes: "Thursday basic, Friday advanced" and a festival with
  fifteen workshops from different teachers. A person opens one link, sees
  everything organized by day and picks where to go.

  The dates do not live here: they are the `min` and `max` of the child
  workshops. A denormalized column would lie the moment a workshop was rescheduled.
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
    # Closed price for the set. Null means single enrollment only, each workshop on its own.
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

  @doc "true when there is a closed price for the set."
  @spec pacote?(t()) :: boolean()
  def pacote?(%__MODULE__{price_cents: cents}) when is_integer(cents) and cents > 0, do: true
  def pacote?(%__MODULE__{}), do: false

  @doc "Stores or removes the flyer. The path comes from the storage, never from the user."
  def flyer_changeset(program, flyer_path) do
    change(program, flyer_path: flyer_path)
  end

  @doc "Muda o estado (publicar, cancelar, voltar a rascunho)."
  def status_changeset(program, status) when status in [:draft, :published, :cancelled] do
    change(program, status: status)
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)

  # Same shape as the Workshop slug: readable plus a short suffix, because the
  # link goes to a WhatsApp group and cannot be guessable.
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

    prefix = if base == "", do: "program", else: base
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

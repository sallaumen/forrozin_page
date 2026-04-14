defmodule Forrozin.Encyclopedia.Subsection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias Forrozin.Encyclopedia.{Section, Step}

  @required_fields [:title, :position, :section_id]
  @optional_fields [:note]

  schema "subsecoes" do
    field :title, :string
    field :note, :string
    field :position, :integer

    belongs_to :section, Section
    has_many :steps, Step, foreign_key: :subsection_id

    timestamps()
  end

  def changeset(subsection, attrs) do
    subsection
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:section_id)
  end
end

defmodule Forrozin.Encyclopedia.Section do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias Forrozin.Encyclopedia.{Category, Step, Subsection}

  @required_fields [:title, :position]
  @optional_fields [:num, :code, :description, :note, :category_id]

  schema "secoes" do
    field :num, :integer
    field :title, :string
    field :code, :string
    field :description, :string
    field :note, :string
    field :position, :integer

    belongs_to :category, Category
    has_many :steps, Step, foreign_key: :section_id
    has_many :subsections, Subsection, foreign_key: :section_id, on_delete: :delete_all

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end

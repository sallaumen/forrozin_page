defmodule OGrupoDeEstudos.Encyclopedia.Step do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia.{Category, Connection, Section, Subsection, TechnicalConcept}

  @required_fields [:code, :name]
  @optional_fields [
    :note,
    :image_path,
    :position,
    :wip,
    :status,
    :highlighted,
    :approved,
    :like_count,
    :category_id,
    :section_id,
    :subsection_id,
    :suggested_by_id,
    :deleted_at
  ]

  schema "steps" do
    field :code, :string
    field :name, :string
    field :note, :string
    field :image_path, :string
    field :position, :integer
    field :wip, :boolean, default: false
    field :status, :string, default: "published"
    field :highlighted, :boolean, default: false
    field :approved, :boolean, default: false
    field :like_count, :integer, default: 0
    field :deleted_at, :naive_datetime

    belongs_to :suggested_by, User, foreign_key: :suggested_by_id
    belongs_to :category, Category
    belongs_to :section, Section
    belongs_to :subsection, Subsection

    many_to_many :technical_concepts, TechnicalConcept,
      join_through: "concept_steps",
      join_keys: [step_id: :id, concept_id: :id]

    has_many :connections_as_source, Connection,
      foreign_key: :source_step_id,
      where: [deleted_at: nil]

    has_many :connections_as_target, Connection,
      foreign_key: :target_step_id,
      where: [deleted_at: nil]

    timestamps()
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:code, min: 1, max: 20)
    |> validate_inclusion(:status, ["published", "draft"])
    |> unique_constraint(:code)
    |> foreign_key_constraint(:category_id)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:subsection_id)
  end
end

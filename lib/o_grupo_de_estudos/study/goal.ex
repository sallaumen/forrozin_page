defmodule OGrupoDeEstudos.Study.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "study_goals" do
    field :body, :string
    field :completed, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :owner_user, OGrupoDeEstudos.Accounts.User
    belongs_to :teacher_student_link, OGrupoDeEstudos.Study.TeacherStudentLink

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:body, :completed, :position, :owner_user_id, :teacher_student_link_id])
    |> validate_required([:body])
    |> validate_length(:body, max: 500)
    |> validate_owner_xor()
  end

  # Uma meta pertence a exatamente um dono: o aluno (pessoal) ou o vínculo
  # professor-aluno (compartilhada), nunca ambos nem nenhum.
  defp validate_owner_xor(changeset) do
    owner = get_field(changeset, :owner_user_id)
    link = get_field(changeset, :teacher_student_link_id)

    case {owner, link} do
      {nil, nil} ->
        add_error(changeset, :owner_user_id, "é obrigatório (meta pessoal ou compartilhada)")

      {owner, link} when not is_nil(owner) and not is_nil(link) ->
        add_error(
          changeset,
          :owner_user_id,
          "não pode ser pessoal e compartilhada ao mesmo tempo"
        )

      _ ->
        changeset
    end
  end
end

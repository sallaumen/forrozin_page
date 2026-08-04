defmodule OGrupoDeEstudos.Workshops.WorkshopTeacher do
  @moduledoc """
  Who teaches a workshop.

  Separate from who organizes on purpose: producing someone else's class is the
  common case, and before that the creator became a teacher by omission.

  Either a site account or a written name, never both: a visiting teacher does not
  always have an account, and waiting for the account to exist before announcing
  the class would hold up the real world for the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_teachers" do
    belongs_to :workshop, Workshop
    belongs_to :user, User

    field :display_name, :string
    field :position, :integer, default: 1

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [:workshop_id, :user_id, :display_name, :position])
    |> update_change(:display_name, &trim/1)
    |> validate_required([:workshop_id, :position])
    |> validate_length(:display_name, max: 120)
    |> validate_conta_ou_nome()
    |> unique_constraint([:workshop_id, :user_id], name: :workshop_teachers_conta_unica_index)
    |> check_constraint(:user_id, name: :conta_ou_nome)
  end

  defp validate_conta_ou_nome(changeset) do
    conta = get_field(changeset, :user_id)
    nome = get_field(changeset, :display_name)

    case {conta, nome} do
      {nil, nil} -> add_error(changeset, :display_name, "informe uma conta ou um nome")
      {conta, nome} when not is_nil(conta) and not is_nil(nome) -> so_a_conta(changeset)
      _um_dos_dois -> changeset
    end
  end

  # An account beats a written name: it brings photo and profile, which is the
  # point of featuring the teacher.
  defp so_a_conta(changeset), do: put_change(changeset, :display_name, nil)

  defp trim(nil), do: nil

  defp trim(valor) do
    case String.trim(valor) do
      "" -> nil
      limpo -> limpo
    end
  end
end

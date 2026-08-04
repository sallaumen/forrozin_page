defmodule OGrupoDeEstudos.Workshops.WorkshopTeacher do
  @moduledoc """
  Quem dá a aula num workshop.

  Separado de quem organiza de propósito: produzir a aula de outra pessoa é o
  caso comum, e antes o criador virava professor por omissão.

  Ou uma conta do site, ou um nome escrito, nunca os dois: professor de fora
  nem sempre tem cadastro, e esperar a conta existir para poder divulgar a
  aula seria travar o mundo real por causa do banco.
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

  # Conta ganha do nome escrito: ela traz foto e perfil, que é o ponto de
  # divulgar o professor.
  defp so_a_conta(changeset), do: put_change(changeset, :display_name, nil)

  defp trim(nil), do: nil

  defp trim(valor) do
    case String.trim(valor) do
      "" -> nil
      limpo -> limpo
    end
  end
end

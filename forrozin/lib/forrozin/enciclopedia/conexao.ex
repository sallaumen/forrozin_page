defmodule Forrozin.Enciclopedia.Conexao do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @tipos_validos ~w(entrada saida)

  schema "conexoes_passos" do
    field :tipo, :string
    field :rotulo, :string
    field :descricao, :string

    belongs_to :passo_origem, Forrozin.Enciclopedia.Passo
    belongs_to :passo_destino, Forrozin.Enciclopedia.Passo

    timestamps()
  end

  @campos_obrigatorios [:tipo, :passo_origem_id, :passo_destino_id]
  @campos_opcionais [:rotulo, :descricao]

  @doc """
  Valida uma conexão direcional entre dois passos.

  O tipo indica a relação: "entrada" (pode-se vir deste passo)
  ou "saida" (pode-se ir para este passo).
  Juntos formam o grafo de navegação da enciclopédia.
  """
  def changeset(conexao, attrs) do
    conexao
    |> cast(attrs, @campos_obrigatorios ++ @campos_opcionais)
    |> validate_required(@campos_obrigatorios)
    |> validate_inclusion(:tipo, @tipos_validos)
    |> unique_constraint([:passo_origem_id, :passo_destino_id, :tipo],
      name: :conexoes_passos_passo_origem_id_passo_destino_id_tipo_index
    )
    |> foreign_key_constraint(:passo_origem_id)
    |> foreign_key_constraint(:passo_destino_id)
  end
end

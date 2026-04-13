defmodule Forrozin.Enciclopedia.Passo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_validos ~w(publicado rascunho)

  schema "passos" do
    field :codigo, :string
    field :nome, :string
    field :nota, :string
    field :wip, :boolean, default: false
    field :caminho_imagem, :string
    field :status, :string, default: "publicado"
    field :posicao, :integer

    belongs_to :categoria, Forrozin.Enciclopedia.Categoria
    belongs_to :secao, Forrozin.Enciclopedia.Secao
    belongs_to :subsecao, Forrozin.Enciclopedia.Subsecao

    many_to_many :conceitos_tecnicos, Forrozin.Enciclopedia.ConceitoTecnico,
      join_through: "conceitos_passos",
      join_keys: [passo_id: :id, conceito_id: :id]

    has_many :conexoes_como_origem, Forrozin.Enciclopedia.Conexao, foreign_key: :passo_origem_id

    has_many :conexoes_como_destino, Forrozin.Enciclopedia.Conexao, foreign_key: :passo_destino_id

    timestamps()
  end

  @campos_obrigatorios [:codigo, :nome, :posicao]
  @campos_opcionais [
    :nota,
    :wip,
    :caminho_imagem,
    :status,
    :categoria_id,
    :secao_id,
    :subsecao_id
  ]

  @doc """
  Valida um passo da enciclopédia.

  O código é o identificador único do passo (ex: "BF", "HF-SRS", "GP-D").
  Passos com `wip: true` são restritos — visíveis apenas a usuários com permissão.
  O status controla se o passo aparece na API pública.
  """
  def changeset(passo, attrs) do
    passo
    |> cast(attrs, @campos_obrigatorios ++ @campos_opcionais)
    |> validate_required(@campos_obrigatorios)
    |> validate_inclusion(:status, @status_validos)
    |> unique_constraint(:codigo)
    |> foreign_key_constraint(:categoria_id)
    |> foreign_key_constraint(:secao_id)
    |> foreign_key_constraint(:subsecao_id)
  end
end

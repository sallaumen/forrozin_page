defmodule Forrozin.Enciclopedia.Secao do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "secoes" do
    field :num, :integer
    field :titulo, :string
    field :codigo, :string
    field :descricao, :string
    field :nota, :string
    field :posicao, :integer

    belongs_to :categoria, Forrozin.Enciclopedia.Categoria
    has_many :subsecoes, Forrozin.Enciclopedia.Subsecao, on_delete: :delete_all
    has_many :passos, Forrozin.Enciclopedia.Passo

    timestamps()
  end

  @campos_obrigatorios [:titulo, :posicao]
  @campos_opcionais [:num, :codigo, :descricao, :nota, :categoria_id]

  @doc """
  Valida uma seção da enciclopédia.

  Apenas título e posição são obrigatórios. O campo `num` é nulo
  nas seções de convenções e conceitos técnicos.
  """
  def changeset(secao, attrs) do
    secao
    |> cast(attrs, @campos_obrigatorios ++ @campos_opcionais)
    |> validate_required(@campos_obrigatorios)
  end
end

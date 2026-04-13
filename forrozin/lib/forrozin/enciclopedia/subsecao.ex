defmodule Forrozin.Enciclopedia.Subsecao do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subsecoes" do
    field :titulo, :string
    field :nota, :string
    field :posicao, :integer

    belongs_to :secao, Forrozin.Enciclopedia.Secao
    has_many :passos, Forrozin.Enciclopedia.Passo, on_delete: :nilify_all

    timestamps()
  end

  @campos_obrigatorios [:titulo, :posicao, :secao_id]
  @campos_opcionais [:nota]

  @doc """
  Valida uma subseção dentro de uma seção.

  Usada para agrupar passos dentro de seções maiores,
  como as entradas do Giro Paulista ou variações de giro.
  """
  def changeset(subsecao, attrs) do
    subsecao
    |> cast(attrs, @campos_obrigatorios ++ @campos_opcionais)
    |> validate_required(@campos_obrigatorios)
    |> foreign_key_constraint(:secao_id)
  end
end

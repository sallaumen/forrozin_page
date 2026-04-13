defmodule Forrozin.Enciclopedia.PassoTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia.Passo

  describe "changeset/2" do
    test "válido com todos os campos obrigatórios" do
      secao = insert(:secao)
      attrs = %{codigo: "BF", nome: "Base frontal", posicao: 0, secao_id: secao.id}
      assert %{valid?: true} = Passo.changeset(%Passo{}, attrs)
    end

    test "status padrão é publicado" do
      secao = insert(:secao)
      attrs = %{codigo: "BF", nome: "Base frontal", posicao: 0, secao_id: secao.id}
      changeset = Passo.changeset(%Passo{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "publicado"
    end

    test "wip padrão é false" do
      secao = insert(:secao)
      attrs = %{codigo: "BF", nome: "Base frontal", posicao: 0, secao_id: secao.id}
      changeset = Passo.changeset(%Passo{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :wip) == false
    end

    test "inválido sem código" do
      secao = insert(:secao)
      attrs = %{nome: "Base frontal", posicao: 0, secao_id: secao.id}
      changeset = Passo.changeset(%Passo{}, attrs)
      assert "can't be blank" in errors_on(changeset).codigo
    end

    test "inválido sem nome" do
      secao = insert(:secao)
      attrs = %{codigo: "BF", posicao: 0, secao_id: secao.id}
      changeset = Passo.changeset(%Passo{}, attrs)
      assert "can't be blank" in errors_on(changeset).nome
    end

    test "status deve ser publicado ou rascunho" do
      secao = insert(:secao)

      attrs = %{
        codigo: "BF",
        nome: "Base frontal",
        posicao: 0,
        secao_id: secao.id,
        status: "invalido"
      }

      changeset = Passo.changeset(%Passo{}, attrs)
      assert "is invalid" in errors_on(changeset).status
    end

    test "código deve ser único no banco" do
      insert(:passo, codigo: "BF")
      secao = insert(:secao)

      {:error, changeset} =
        %Passo{}
        |> Passo.changeset(%{codigo: "BF", nome: "Outro", posicao: 1, secao_id: secao.id})
        |> Forrozin.Repo.insert()

      assert "has already been taken" in errors_on(changeset).codigo
    end
  end
end

defmodule OGrupoDeEstudos.Encyclopedia.Seeder do
  @moduledoc """
  Seed inicial da enciclopédia de forró roots.

  Os dados (categorias, seções, subseções, passos e conceitos técnicos)
  vivem em `priv/data/encyclopedia_seed.json`; este módulo só orquestra:
  lê, monta os changesets e insere. Idempotente: chamadas subsequentes
  retornam `:already_seeded` sem modificar o banco.
  """

  alias OGrupoDeEstudos.Encyclopedia.{Category, Section, Step, Subsection, TechnicalConcept}
  alias OGrupoDeEstudos.Repo

  @seed_file Path.join(["data", "encyclopedia_seed.json"])

  @doc """
  Executa o seed inicial da enciclopédia. Retorna `:ok` na primeira execução e
  `:already_seeded` nas subsequentes — seguro chamar múltiplas vezes.
  """
  def seed! do
    if Repo.exists?(Category) do
      :already_seeded
    else
      run_seed!(load_data!())
      :ok
    end
  end

  defp run_seed!(data) do
    {:ok, _} =
      Repo.transaction(fn ->
        categories_map = seed_categories!(data["categories"])
        seed_sections!(data["sections"], data["hf_cards"], categories_map)
        seed_technical_concepts!(data["conceitos"])
      end)
  end

  defp load_data! do
    :o_grupo_de_estudos
    |> Application.app_dir("priv")
    |> Path.join(@seed_file)
    |> File.read!()
    |> Jason.decode!()
  end

  # ---------------------------------------------------------------------------
  # Privado — categorias
  # ---------------------------------------------------------------------------

  defp seed_categories!(categories) do
    Enum.reduce(categories, %{}, fn cat, acc ->
      inserted =
        %Category{}
        |> Category.changeset(%{name: cat["name"], label: cat["label"], color: cat["color"]})
        |> Repo.insert!()

      Map.put(acc, cat["name"], inserted.id)
    end)
  end

  # ---------------------------------------------------------------------------
  # Privado — seções, subseções e passos
  # ---------------------------------------------------------------------------

  defp seed_sections!(sections, hf_cards, categories_map) do
    sections
    |> Enum.with_index(1)
    |> Enum.each(fn {section_data, position} ->
      cat_id = categories_map[section_data["category"]]
      section = insert_section!(section_data, position, cat_id)

      seed_steps!(section_data["steps"] || [], hf_cards, section.id, nil, cat_id)
      seed_subsections!(section_data["subsections"] || [], hf_cards, section.id, cat_id)
    end)
  end

  defp insert_section!(section_data, position, cat_id) do
    %Section{}
    |> Section.changeset(%{
      title: section_data["title"],
      code: section_data["code"],
      num: section_data["num"],
      description: section_data["description"],
      note: section_data["note"],
      position: position,
      category_id: cat_id
    })
    |> Repo.insert!()
  end

  defp seed_subsections!(subsections, hf_cards, section_id, cat_id) do
    subsections
    |> Enum.with_index(1)
    |> Enum.each(fn {subsection_data, sub_position} ->
      subsection =
        %Subsection{}
        |> Subsection.changeset(%{
          title: subsection_data["title"],
          note: subsection_data["note"],
          position: sub_position,
          section_id: section_id
        })
        |> Repo.insert!()

      seed_steps!(subsection_data["steps"] || [], hf_cards, section_id, subsection.id, cat_id)
    end)
  end

  defp seed_steps!(steps, hf_cards, section_id, subsection_id, cat_id) do
    steps
    |> Enum.with_index(1)
    |> Enum.each(fn {step_data, position} ->
      %Step{}
      |> Step.changeset(
        step_attrs(step_data, hf_cards, position, section_id, subsection_id, cat_id)
      )
      |> Repo.insert(on_conflict: :nothing, conflict_target: :code)
    end)
  end

  defp step_attrs(step_data, hf_cards, position, section_id, subsection_id, cat_id) do
    code = step_data["code"]

    %{
      code: code,
      name: step_data["name"],
      note: step_data["note"],
      wip: Map.get(step_data, "wip", false) or String.starts_with?(code, "HF-"),
      image_path: if(code in hf_cards, do: "images/#{code}.jpg"),
      status: :published,
      position: position,
      section_id: section_id,
      subsection_id: subsection_id,
      category_id: cat_id
    }
  end

  # ---------------------------------------------------------------------------
  # Privado — conceitos técnicos
  # ---------------------------------------------------------------------------

  defp seed_technical_concepts!(conceitos) do
    Enum.each(conceitos, fn conceito ->
      %TechnicalConcept{}
      |> TechnicalConcept.changeset(%{
        title: conceito["title"],
        description: conceito["description"]
      })
      |> Repo.insert!()
    end)
  end
end

defmodule Forrozin.Repo.Migrations.LimparPassosCompostos do
  use Ecto.Migration

  @moduledoc """
  Remove passos que são na verdade arestas disfarçadas (compostos, duplicatas,
  subpassos sem entidade própria). Cada código foi analisado em ANALISE_PASSOS_GRAFO.md.

  Também renomeia códigos problemáticos (parênteses no código) e simplifica nomes
  de arrastes.

  Idempotente: DELETE/UPDATE com WHERE — não falha se o registro não existe.
  """

  def up do
    # --- Remoção de compostos e duplicatas --------------------------------
    execute("""
    DELETE FROM passos WHERE codigo IN (
      'PI-ímpar', 'AB-D',
      'PI-AL', 'PI-B', 'PI-G',
      'DA-R > CA', 'DA-R > TR', 'DA-R > SCSP', 'DA-R > footwork',
      'P1', 'PE-SC-E', 'GPS', 'SCSP-TE', 'GS-J-GPC',
      'AB-GP-D', 'SC-E-BA', 'ARD-TP', 'ARE-TP', 'TR-ARM-PE'
    )
    """)

    # --- Renomeações de código --------------------------------------------
    execute("UPDATE passos SET codigo = 'PE-PD' WHERE codigo = 'PE(pd)'")
    execute("UPDATE passos SET codigo = 'SCSP-PDI-ET-BE' WHERE codigo = 'SCSP(pdi)-ET-BE'")

    # --- Simplificação de nomes -------------------------------------------
    execute("UPDATE passos SET nome = 'Arraste direita' WHERE codigo = 'ARD'")
    execute("UPDATE passos SET nome = 'Arraste esquerda' WHERE codigo = 'ARE'")
  end

  def down do
    raise "Irreversível — restaurar a partir do backup JSON se necessário."
  end
end

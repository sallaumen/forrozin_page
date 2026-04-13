defmodule Mix.Tasks.Forrozin.ExtrairConexoes do
  @shortdoc "Extrai conexões implícitas nas notas dos passos e insere no banco"

  @moduledoc """
  Interpreta os campos `nota` dos passos do semeador e insere as conexões
  que estão descritas textualmente (Entradas:/Saídas:) como arestas no grafo.

  Idempotente: usa `on_conflict: :nothing`.

  ## Uso

      mix forrozin.extrair_conexoes

  """

  use Mix.Task

  @requirements ["app.start"]

  # Conexões extraídas manualmente das notas do semeador.
  # Formato: {codigo_origem, codigo_destino}
  # Resolução de ambiguidades: "CA" → CA-E, "PE" → PE-E-E, "base" → BF
  @conexoes [
    # SC — Sacada simples: "Saídas: GP, TRD, PE, CA, PI"
    {"SC", "GP"},
    {"SC", "TRD"},
    {"SC", "PE-E-E"},
    {"SC", "CA-E"},
    {"SC", "PI"},

    # SC-E — Sacada de esquerda: "Saídas: PE-E-E, GP" (PE-SC-E removido → aresta nomeada)
    {"SC-E", "PE-E-E"},
    {"SC-E", "GP"},

    # TR-FS e TR-FC: "Entradas: DA-R, intenção de sacada"
    {"DA-R", "TR-FS"},
    {"DA-R", "TR-FC"},

    # TR-ARM — Trava armada: "Saídas: GP, TRD"
    {"TR-ARM", "GP"},
    {"TR-ARM", "TRD"},

    # ARM-D — Armar pra direita: "Saídas: TR-ARM, TR-E"
    {"ARM-D", "TR-ARM"},
    {"ARM-D", "TR-E"},

    # PE-E-E — Pescada esquerda-esquerda: "Saídas: PI, GS, BF"
    {"PE-E-E", "PI"},
    {"PE-E-E", "GS"},
    {"PE-E-E", "BF"},

    # CA-E — Caminhada esquerda: "Entradas: intenção de sacada, DA-R, SC. Saídas: PE-E-E, SC, BF"
    {"DA-R", "CA-E"},
    {"SC", "CA-E"},
    {"CA-E", "PE-E-E"},
    {"CA-E", "SC"},
    {"CA-E", "BF"},

    # CA-F — Caminhada frontal: "Saídas: PI, PI-INV"
    {"CA-F", "PI"},
    {"CA-F", "PI-INV"},

    # CA-CT — Caminhada com contorno: "Saídas: SC, GP, TRD"
    {"CA-CT", "SC"},
    {"CA-CT", "GP"},
    {"CA-CT", "TRD"},

    # CA-TZ — Caminhada cruzada: finaliza em trava
    {"CA-TZ", "TR-E"},

    # DA-R — bidirecional com passos de dança aberta
    {"DA-R", "CA-E-DA"},
    {"CA-E-DA", "DA-R"},
    {"DA-R", "TR-DA"},
    {"TR-DA", "DA-R"},
    {"DA-R", "SCSP-DA"},
    {"SCSP-DA", "DA-R"},

    # GP — Giro paulista: "Entradas: DA-R, PI (ímpar), PMB, TR-ARM. Saídas: qualquer base, PI, CA"
    {"DA-R", "GP"},
    {"PI", "GP"},
    {"PMB", "GP"},
    {"TR-ARM", "GP"},
    {"GP", "BF"},
    {"GP", "PI"},
    {"GP", "CA-E"},

    # GPC — Giro paulista de costas: "Entrada: GS"
    {"GS", "GPC"},

    # GP-D — Paulista duplo: entrada via abraço lateral
    {"AB-T", "GP-D"},

    # BL → GP (P1 removido — virou esta aresta)
    {"BL", "GP"},

    # BE → GPE: "Entrada a partir da base estranha (BE)"
    {"BE", "GPE"},

    # IV — Inversão: "Saídas: SC, CA, TR, GP, TRD"
    {"IV", "SC"},
    {"IV", "CA-E"},
    {"IV", "GP"},
    {"IV", "TRD"},

    # IV-CT: entrada a partir de IV; saída para TRD
    {"IV", "IV-CT"},
    {"IV-CT", "TRD"},

    # PI — Pião horário: "Saídas: GP (ímpar), PE, TR-ARM, TRD"
    {"PI", "PE-E-E"},
    {"PI", "TR-ARM"},
    {"PI", "TRD"},

    # Entradas no PI
    {"BF", "PI"},
    {"BTR", "PI"},

    # GS — Giro simples: "Saídas: BF, AB, MC, PI"
    {"GS", "BF"},
    {"GS", "PI"},

    # BA — Balanço: a partir de BF; saídas SC-E e arrastes
    {"BF", "BA"},
    {"BA", "SC-E"},
    {"BA", "ARD"},
    {"BA", "ARE"},

    # Arrastes — a partir de BF e BA; bidirecionais entre si
    {"BF", "ARD"},
    {"BF", "ARE"},
    {"ARD", "ARE"},
    {"ARE", "ARD"},

    # SCSP → TR-E (SCSP-TE removido → aresta nomeada)
    {"SCSP", "TR-E"},

    # TR-E → PE-E-E (TR-ARM-PE removido → aresta nomeada)
    {"TR-E", "PE-E-E"},

    # CHQ → PMB (PMB: "Saída do CHQ")
    {"CHQ", "PMB"},

    # PMB — Pimba: "Saídas: GP, TRD, TR, CA"
    {"PMB", "TRD"},
    {"PMB", "CA-E"},

    # TRD — Trocadilho: "Entradas: SC, PMB, TR-ARM, CA-CT, IV-CT. Saídas: BF, CA, PI"
    {"SC", "TRD"},
    {"PMB", "TRD"},
    {"TR-ARM", "TRD"},
    {"CA-CT", "TRD"},
    {"TRD", "BF"},
    {"TRD", "CA-E"},
    {"TRD", "PI"}
  ]

  @impl Mix.Task
  def run(_args) do
    alias Forrozin.{Admin, Enciclopedia}

    Mix.shell().info("Extraindo conexões implícitas das notas...")

    passos = Enciclopedia.listar_todos_passos_mapa()

    resultados =
      @conexoes
      |> Enum.uniq()
      |> Enum.map(fn {orig, dest} ->
        with {:origem, %{id: orig_id}} <- {:origem, Map.get(passos, orig)},
             {:destino, %{id: dest_id}} <- {:destino, Map.get(passos, dest)} do
          inserir_conexao(Admin, orig_id, dest_id, orig, dest)
        else
          {:origem, nil} -> {:passo_nao_encontrado, "#{orig} (origem)"}
          {:destino, nil} -> {:passo_nao_encontrado, "#{dest} (destino)"}
        end
      end)

    inseridas = Enum.count(resultados, &match?({:inserida, _}, &1))
    duplicadas = Enum.count(resultados, &match?({:duplicada, _}, &1))
    nao_encontradas = Enum.filter(resultados, &match?({:passo_nao_encontrado, _}, &1))

    Mix.shell().info("  ✓ #{inseridas} conexões inseridas")
    Mix.shell().info("  · #{duplicadas} já existiam (ignoradas)")

    if nao_encontradas != [] do
      Mix.shell().info("\n  ⚠ Passos não encontrados no banco:")

      Enum.each(nao_encontradas, fn {_, msg} ->
        Mix.shell().info("    - #{msg}")
      end)
    end

    Mix.shell().info("\nPronto. Rode `mix forrozin.restaurar_backup` para salvar em backup.")
  end

  defp inserir_conexao(admin, orig_id, dest_id, orig, dest) do
    case admin.criar_conexao(%{passo_origem_id: orig_id, passo_destino_id: dest_id, tipo: "saida"}) do
      {:ok, _} -> {:inserida, "#{orig} → #{dest}"}
      {:error, _} -> {:duplicada, "#{orig} → #{dest}"}
    end
  end
end

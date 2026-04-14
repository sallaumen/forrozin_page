defmodule Mix.Tasks.Forrozin.ExtractConnections do
  @shortdoc "Extracts implicit connections from step notes and inserts them into the database"

  @moduledoc """
  Interprets the `note` fields of seeder steps and inserts connections
  described textually (Entries:/Exits:) as edges in the graph.

  Idempotent: uses `on_conflict: :nothing`.

  ## Usage

      mix forrozin.extract_connections

  """

  use Mix.Task

  @requirements ["app.start"]

  # Connections extracted manually from seeder notes.
  # Format: {source_code, target_code}
  # Disambiguation: "CA" → CA-E, "PE" → PE-E-E, "base" → BF
  @connections [
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
    alias Forrozin.{Admin, Encyclopedia}

    Mix.shell().info("Extracting implicit connections from notes...")

    steps = Encyclopedia.list_all_steps_map()

    results =
      @connections
      |> Enum.uniq()
      |> Enum.map(fn {source_code, target_code} ->
        with {:source, %{id: source_id}} <- {:source, Map.get(steps, source_code)},
             {:target, %{id: target_id}} <- {:target, Map.get(steps, target_code)} do
          insert_connection(Admin, source_id, target_id, source_code, target_code)
        else
          {:source, nil} -> {:step_not_found, "#{source_code} (source)"}
          {:target, nil} -> {:step_not_found, "#{target_code} (target)"}
        end
      end)

    inserted = Enum.count(results, &match?({:inserted, _}, &1))
    duplicated = Enum.count(results, &match?({:duplicated, _}, &1))
    not_found = Enum.filter(results, &match?({:step_not_found, _}, &1))

    Mix.shell().info("  ✓ #{inserted} connections inserted")
    Mix.shell().info("  · #{duplicated} already existed (ignored)")

    if not_found != [] do
      Mix.shell().info("\n  ⚠ Steps not found in database:")

      Enum.each(not_found, fn {_, msg} ->
        Mix.shell().info("    - #{msg}")
      end)
    end

    Mix.shell().info("\nDone. Run `mix forrozin.restore_backup` to save a backup.")
  end

  defp insert_connection(admin, source_id, target_id, source_code, target_code) do
    case admin.create_connection(%{source_step_id: source_id, target_step_id: target_id, type: "exit"}) do
      {:ok, _} -> {:inserted, "#{source_code} → #{target_code}"}
      {:error, _} -> {:duplicated, "#{source_code} → #{target_code}"}
    end
  end
end

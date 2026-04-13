defmodule Forrozin.Admin.Backup do
  @moduledoc """
  Backup e restauração do banco de dados em formato JSON.

  Gera snapshots das tabelas da enciclopédia em `priv/backups/`.
  Cada arquivo é nomeado `backup_YYYYMMDD_HHMMSS.json`.
  Mantém os últimos 48 arquivos (≈ 2 dias de backups por hora).

  ## Uso

      # Gerar backup no diretório padrão
      Forrozin.Admin.Backup.criar_backup!()

      # Listar backups disponíveis
      Forrozin.Admin.Backup.listar_backups()

      # Restaurar a partir de um arquivo
      Forrozin.Admin.Backup.restaurar_backup!("priv/backups/backup_20260411_130000.json")
  """

  alias Forrozin.Enciclopedia.{Categoria, ConceitoTecnico, Conexao, Passo, Secao, Subsecao}
  alias Forrozin.Repo

  @max_backups 48

  @schemas_ordenados [
    {"categorias", Categoria},
    {"secoes", Secao},
    {"subsecoes", Subsecao},
    {"passos", Passo},
    {"conceitos_tecnicos", ConceitoTecnico},
    {"conexoes_passos", Conexao}
  ]

  # ---------------------------------------------------------------------------
  # Público
  # ---------------------------------------------------------------------------

  @doc """
  Cria um backup JSON no diretório especificado.

  Retorna o caminho do arquivo criado. Remove arquivos antigos mantendo
  apenas os últimos `#{@max_backups}`.
  """
  def criar_backup!(dir \\ default_dir()) do
    File.mkdir_p!(dir)
    caminho = Path.join(dir, nome_arquivo())

    dados = %{
      "versao" => "1",
      "criado_em" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "tabelas" =>
        Map.new(@schemas_ordenados, fn {nome, schema} ->
          {nome, dump_schema(schema)}
        end)
        |> Map.put("conceitos_passos", dump_join_table())
    }

    File.write!(caminho, Jason.encode!(dados, pretty: true))
    limpar_antigos!(dir)
    caminho
  end

  @doc """
  Restaura dados a partir de um arquivo de backup.

  Usa `on_conflict: :nothing` — idempotente, não sobrescreve dados existentes.
  Retorna `:ok`.
  """
  def restaurar_backup!(path) do
    dados = path |> File.read!() |> Jason.decode!()
    tabelas = dados["tabelas"]

    Repo.transaction(fn ->
      for {nome, schema} <- @schemas_ordenados do
        restaurar_schema(schema, tabelas[nome] || [])
      end

      restaurar_join_table(tabelas["conceitos_passos"] || [])
    end)

    :ok
  end

  @doc """
  Lista os arquivos de backup disponíveis no diretório, do mais recente ao mais antigo.
  """
  def listar_backups(dir \\ default_dir()) do
    case File.ls(dir) do
      {:ok, arquivos} ->
        arquivos
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort(:desc)
        |> Enum.map(&Path.join(dir, &1))

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Privado — dump
  # ---------------------------------------------------------------------------

  defp dump_schema(schema) do
    campos = schema.__schema__(:fields)

    Repo.all(schema)
    |> Enum.map(fn registro ->
      Map.new(campos, fn campo ->
        {Atom.to_string(campo), serializar_valor(Map.get(registro, campo))}
      end)
    end)
  end

  defp dump_join_table do
    %{rows: rows, columns: cols} =
      Repo.query!("SELECT conceito_id::text, passo_id::text FROM conceitos_passos")

    Enum.map(rows, fn row -> Map.new(Enum.zip(cols, row)) end)
  end

  defp serializar_valor(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serializar_valor(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serializar_valor(valor), do: valor

  # ---------------------------------------------------------------------------
  # Privado — restore
  # ---------------------------------------------------------------------------

  defp restaurar_schema(schema, registros) do
    tipos =
      Map.new(schema.__schema__(:fields), fn campo ->
        {Atom.to_string(campo), schema.__schema__(:type, campo)}
      end)

    rows =
      Enum.map(registros, fn registro ->
        Map.new(registro, fn {k, v} ->
          {String.to_existing_atom(k), deserializar_valor(v, tipos[k])}
        end)
      end)

    Repo.insert_all(schema, rows, on_conflict: :nothing)
  end

  defp restaurar_join_table(registros) do
    rows =
      Enum.map(registros, fn %{"conceito_id" => c, "passo_id" => p} ->
        %{conceito_id: c, passo_id: p}
      end)

    unless rows == [] do
      Repo.insert_all("conceitos_passos", rows, on_conflict: :nothing)
    end
  end

  defp deserializar_valor(v, :naive_datetime) when is_binary(v) do
    {:ok, dt} = NaiveDateTime.from_iso8601(v)
    dt
  end

  defp deserializar_valor(v, _tipo), do: v

  # ---------------------------------------------------------------------------
  # Privado — utilitários
  # ---------------------------------------------------------------------------

  defp nome_arquivo do
    now = NaiveDateTime.utc_now()
    ts = Calendar.strftime(now, "%Y%m%d_%H%M%S")
    "backup_#{ts}.json"
  end

  defp limpar_antigos!(dir) do
    arquivos =
      File.ls!(dir)
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.sort(:desc)

    arquivos
    |> Enum.drop(@max_backups)
    |> Enum.each(fn nome -> File.rm!(Path.join(dir, nome)) end)
  end

  defp default_dir do
    Path.join([Application.app_dir(:forrozin, "priv"), "backups"])
  end
end

defmodule Forrozin.Admin.Backup do
  @moduledoc """
  Database backup and restore in JSON format.

  Generates snapshots of the encyclopedia tables in `priv/backups/`.
  Each file is named `backup_YYYYMMDD_HHMMSS.json`.
  Keeps the last 48 files (≈ 2 days of hourly backups).

  ## Usage

      # Generate backup in the default directory
      Forrozin.Admin.Backup.create_backup!()

      # List available backups
      Forrozin.Admin.Backup.list_backups()

      # Restore from a file
      Forrozin.Admin.Backup.restore_backup!("priv/backups/backup_20260411_130000.json")
  """

  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Connection, Step, Section, Subsection}
  alias Forrozin.Repo

  @max_backups 48

  @ordered_schemas [
    {"categorias", Category},
    {"secoes", Section},
    {"subsecoes", Subsection},
    {"passos", Step},
    {"conceitos_tecnicos", TechnicalConcept},
    {"conexoes_passos", Connection}
  ]

  # ---------------------------------------------------------------------------
  # Public
  # ---------------------------------------------------------------------------

  @doc """
  Creates a JSON backup in the specified directory.

  Returns the path of the created file. Removes old files keeping
  only the last `#{@max_backups}`.
  """
  def create_backup!(dir \\ default_dir()) do
    File.mkdir_p!(dir)
    path = Path.join(dir, filename())

    data = %{
      "versao" => "1",
      "criado_em" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "tabelas" =>
        Map.new(@ordered_schemas, fn {nome, schema} ->
          {nome, dump_schema(schema)}
        end)
        |> Map.put("conceitos_passos", dump_join_table())
    }

    File.write!(path, Jason.encode!(data, pretty: true))
    cleanup_old!(dir)
    path
  end

  @doc """
  Restores data from a backup file.

  Uses `on_conflict: :nothing` — idempotent, does not overwrite existing data.
  Returns `:ok`.
  """
  def restore_backup!(path) do
    data = path |> File.read!() |> Jason.decode!()
    tables = data["tabelas"]

    Repo.transaction(fn ->
      for {nome, schema} <- @ordered_schemas do
        restore_schema(schema, tables[nome] || [])
      end

      restore_join_table(tables["conceitos_passos"] || [])
    end)

    :ok
  end

  @doc """
  Lists available backup files in the directory, from most recent to oldest.
  """
  def list_backups(dir \\ default_dir()) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort(:desc)
        |> Enum.map(&Path.join(dir, &1))

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private — dump
  # ---------------------------------------------------------------------------

  defp dump_schema(schema) do
    fields = schema.__schema__(:fields)

    Repo.all(schema)
    |> Enum.map(fn record ->
      Map.new(fields, fn field ->
        {Atom.to_string(field), serialize_value(Map.get(record, field))}
      end)
    end)
  end

  defp dump_join_table do
    %{rows: rows, columns: cols} =
      Repo.query!("SELECT conceito_id::text, passo_id::text FROM conceitos_passos")

    Enum.map(rows, fn row -> Map.new(Enum.zip(cols, row)) end)
  end

  defp serialize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(value), do: value

  # ---------------------------------------------------------------------------
  # Private — restore
  # ---------------------------------------------------------------------------

  defp restore_schema(schema, records) do
    types =
      Map.new(schema.__schema__(:fields), fn field ->
        {Atom.to_string(field), schema.__schema__(:type, field)}
      end)

    rows =
      Enum.map(records, fn record ->
        Map.new(record, fn {k, v} ->
          {String.to_existing_atom(k), deserialize_value(v, types[k])}
        end)
      end)

    Repo.insert_all(schema, rows, on_conflict: :nothing)
  end

  defp restore_join_table(records) do
    rows =
      Enum.map(records, fn %{"conceito_id" => c, "passo_id" => p} ->
        %{conceito_id: c, passo_id: p}
      end)

    unless rows == [] do
      Repo.insert_all("conceitos_passos", rows, on_conflict: :nothing)
    end
  end

  defp deserialize_value(v, :naive_datetime) when is_binary(v) do
    {:ok, dt} = NaiveDateTime.from_iso8601(v)
    dt
  end

  defp deserialize_value(v, _type), do: v

  # ---------------------------------------------------------------------------
  # Private — utilities
  # ---------------------------------------------------------------------------

  defp filename do
    now = NaiveDateTime.utc_now()
    ts = Calendar.strftime(now, "%Y%m%d_%H%M%S")
    "backup_#{ts}.json"
  end

  defp cleanup_old!(dir) do
    files =
      File.ls!(dir)
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.sort(:desc)

    files
    |> Enum.drop(@max_backups)
    |> Enum.each(fn name -> File.rm!(Path.join(dir, name)) end)
  end

  defp default_dir do
    Path.join([Application.app_dir(:forrozin, "priv"), "backups"])
  end
end

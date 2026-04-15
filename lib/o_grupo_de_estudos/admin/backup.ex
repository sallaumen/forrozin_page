defmodule OGrupoDeEstudos.Admin.Backup do
  @moduledoc """
  Database backup and restore in JSON format.

  Generates snapshots of the encyclopedia tables in `priv/backups/`.
  Each file is named `backup_YYYYMMDD_HHMMSS.json`.
  Keeps the last 48 files (≈ 2 days of hourly backups).

  ## Usage

      # Generate backup in the default directory
      OGrupoDeEstudos.Admin.Backup.create_backup!()

      # List available backups
      OGrupoDeEstudos.Admin.Backup.list_backups()

      # Restore from a file
      OGrupoDeEstudos.Admin.Backup.restore_backup!("priv/backups/backup_20260411_130000.json")
  """

  alias OGrupoDeEstudos.Accounts.User

  alias OGrupoDeEstudos.Encyclopedia.{
    Category,
    TechnicalConcept,
    Connection,
    Step,
    Section,
    Subsection,
    StepLink
  }

  alias OGrupoDeEstudos.Engagement.Like
  alias OGrupoDeEstudos.Sequences.{Sequence, SequenceStep}
  alias OGrupoDeEstudos.Repo

  @max_backups 48

  @ordered_schemas [
    {"users", User},
    {"categories", Category},
    {"sections", Section},
    {"subsections", Subsection},
    {"steps", Step},
    {"technical_concepts", TechnicalConcept},
    {"step_connections", Connection},
    {"step_links", StepLink},
    {"sequences", Sequence},
    {"sequence_steps", SequenceStep},
    {"likes", Like}
  ]

  @doc """
  Creates a JSON backup in the specified directory.

  Returns the path of the created file. Removes old files keeping
  only the last `#{@max_backups}`.
  """
  def create_backup!(dir \\ default_dir()) do
    File.mkdir_p!(dir)
    path = Path.join(dir, filename())

    utc_now = DateTime.utc_now()

    data = %{
      "version" => "1",
      "created_at" => DateTime.to_iso8601(utc_now),
      "tables" =>
        Map.new(@ordered_schemas, fn {name, schema} ->
          {name, dump_schema(schema)}
        end)
        |> Map.put("concept_steps", dump_join_table())
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
    tables = data["tables"]

    Repo.transaction(fn ->
      for {name, schema} <- @ordered_schemas do
        restore_schema(schema, tables[name] || [])
      end

      restore_join_table(tables["concept_steps"] || [])
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

  @doc """
  Returns a map of metadata for a backup file path.

  Extracts filename, size (in bytes), and parsed timestamp from the filename.
  Returns `nil` if the file does not exist.

  ## Example

      iex> Backup.backup_info("/priv/backups/backup_20260415_120000.json")
      %{
        path: "/priv/backups/backup_20260415_120000.json",
        filename: "backup_20260415_120000.json",
        size: 42_000,
        timestamp: ~N[2026-04-15 12:00:00]
      }
  """
  def backup_info(path) do
    case File.stat(path) do
      {:ok, stat} ->
        filename = Path.basename(path)

        %{
          path: path,
          filename: filename,
          size: stat.size,
          timestamp: parse_backup_timestamp(filename)
        }

      {:error, _} ->
        nil
    end
  end

  @doc """
  Parses a NaiveDateTime from a backup filename of the form
  `backup_YYYYMMDD_HHMMSS.json`.

  Returns `nil` when the filename does not match the expected pattern.
  """
  def parse_backup_timestamp(filename) do
    case Regex.run(~r/backup_(\d{8})_(\d{6})\.json/, filename) do
      [_, date_part, time_part] ->
        <<y::binary-size(4), mo::binary-size(2), d::binary-size(2)>> = date_part
        <<h::binary-size(2), mi::binary-size(2), s::binary-size(2)>> = time_part

        NaiveDateTime.new(
          String.to_integer(y),
          String.to_integer(mo),
          String.to_integer(d),
          String.to_integer(h),
          String.to_integer(mi),
          String.to_integer(s)
        )
        |> case do
          {:ok, dt} -> dt
          _ -> nil
        end

      _ ->
        nil
    end
  end

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
      Repo.query!("SELECT concept_id::text, step_id::text FROM concept_steps")

    Enum.map(rows, fn row -> Map.new(Enum.zip(cols, row)) end)
  end

  defp serialize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(value), do: value

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
      Enum.map(records, fn %{"concept_id" => c, "step_id" => p} ->
        %{concept_id: c, step_id: p}
      end)

    unless rows == [] do
      Repo.insert_all("concept_steps", rows, on_conflict: :nothing)
    end
  end

  defp deserialize_value(v, :naive_datetime) when is_binary(v) do
    {:ok, dt} = NaiveDateTime.from_iso8601(v)
    dt
  end

  defp deserialize_value(v, _type), do: v

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
    Path.join([Application.app_dir(:o_grupo_de_estudos, "priv"), "backups"])
  end
end

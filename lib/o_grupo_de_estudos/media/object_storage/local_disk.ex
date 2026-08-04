defmodule OGrupoDeEstudos.Media.ObjectStorage.LocalDisk do
  @moduledoc """
  `ObjectStorage.Behaviour` adapter on the local disk.

  In production the bytes live on the Fly volume (`/app/uploads`); in dev, in
  `priv/uploads`. File mechanics only: naming, sizing and permission are decided
  one layer above.
  """

  @behaviour OGrupoDeEstudos.Media.ObjectStorage.Behaviour

  @doc "Writes the source file at the key, creating the folders of the path."
  @impl true
  def put(key, source_path) do
    destino = path(key)
    File.mkdir_p!(Path.dirname(destino))

    case File.cp(source_path, destino) do
      :ok -> :ok
      erro -> erro
    end
  end

  @doc "Deletes the object. Silent when it is already gone."
  @impl true
  def delete(key) do
    case File.rm(path(key)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      erro -> erro
    end
  end

  @impl true
  def exists?(key), do: File.exists?(path(key))

  @doc """
  Keys starting with the prefix, walking into subfolders.

  A key is a flat path in the contract (as in a bucket): a folder is not an object
  and does not show up in the list.
  """
  @impl true
  def list(prefix) do
    pasta = Path.dirname(prefix)
    raiz = dir_path(pasta)

    raiz
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.join(pasta, Path.relative_to(&1, raiz)))
    |> Enum.filter(&String.starts_with?(&1, prefix))
  end

  @doc "On disk, the public URL is the path served by UploadsStatic."
  @impl true
  def public_url(key), do: "/uploads/" <> key

  @doc "A local object is served as a file, straight into send_file."
  @impl true
  def serve(key) do
    caminho = path(key)

    if File.exists?(caminho), do: {:file, caminho}, else: {:error, :not_found}
  end

  @doc "On disk the file is already local: hands over the path, with no copy."
  @impl true
  def with_local_file(key, fun) do
    case serve(key) do
      {:file, caminho} -> {:ok, fun.(caminho)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Free bytes on the uploads volume.

  It exists so the gallery can refuse a new file before the disk fills up:
  failing with a clear message beats blowing up with ENOSPC mid-upload.
  """
  @impl true
  def free_bytes do
    caminho = base_path()
    File.mkdir_p!(caminho)

    case System.cmd("df", ["-k", caminho], stderr_to_stdout: true) do
      {saida, 0} -> parse_df(saida)
      _erro -> :unknown
    end
  rescue
    _e -> :unknown
  end

  defp parse_df(saida) do
    saida
    |> String.split("\n", trim: true)
    |> Enum.at(1)
    |> case do
      nil -> :unknown
      linha -> bytes_livres(String.split(linha, ~r/\s+/, trim: true))
    end
  end

  defp bytes_livres(colunas) when length(colunas) >= 4 do
    case Integer.parse(Enum.at(colunas, 3)) do
      {kb, _} -> kb * 1024
      :error -> :unknown
    end
  end

  defp bytes_livres(_colunas), do: :unknown

  @doc """
  Absolute path of a key in THIS adapter.

  Outside the behaviour on purpose: it only makes sense on disk. Tests use it to
  assert physical presence; domain code should go through `serve/1` or
  `with_local_file/2`.
  """
  @spec path(String.t()) :: String.t()
  def path(key), do: Path.join(base_path(), key)

  defp dir_path(subdir), do: Path.join(base_path(), subdir)

  defp base_path do
    Application.get_env(:o_grupo_de_estudos, :uploads_path, default_path())
  end

  defp default_path do
    if File.dir?("/app/uploads"),
      do: "/app/uploads",
      else: Path.join(:code.priv_dir(:o_grupo_de_estudos), "static/uploads")
  end
end

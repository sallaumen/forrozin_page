defmodule OGrupoDeEstudos.Media.ObjectStorage.LocalDisk do
  @moduledoc """
  Adapter de `ObjectStorage.Behaviour` no disco local.

  Em produção os bytes moram no volume do Fly (`/app/uploads`); em dev, em
  `priv/uploads`. Só mecânica de arquivo: quem decide nome, tamanho e
  permissão está uma camada acima.
  """

  @behaviour OGrupoDeEstudos.Media.ObjectStorage.Behaviour

  @doc "Grava o arquivo de origem na chave, criando as pastas do caminho."
  @impl true
  def put(key, source_path) do
    destino = path(key)
    File.mkdir_p!(Path.dirname(destino))

    case File.cp(source_path, destino) do
      :ok -> :ok
      erro -> erro
    end
  end

  @doc "Apaga o objeto. Silencioso quando já não existe."
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

  @doc "Chaves que começam com o prefixo. A pasta é a parte antes da última /."
  @impl true
  def list(prefix) do
    pasta = Path.dirname(prefix)

    pasta
    |> dir_path()
    |> File.ls()
    |> case do
      {:ok, nomes} ->
        nomes |> Enum.map(&Path.join(pasta, &1)) |> Enum.filter(&match_prefix(&1, prefix))

      {:error, _sem_pasta} ->
        []
    end
  end

  defp match_prefix(key, prefix), do: String.starts_with?(key, prefix)

  @doc "No disco, a URL pública é o caminho servido pelo UploadsStatic."
  @impl true
  def public_url(key), do: "/uploads/" <> key

  @doc "Objeto local se serve por arquivo, direto no send_file."
  @impl true
  def serve(key) do
    caminho = path(key)

    if File.exists?(caminho), do: {:file, caminho}, else: {:error, :not_found}
  end

  @doc "No disco o arquivo já é local: entrega o caminho, sem cópia nenhuma."
  @impl true
  def with_local_file(key, fun) do
    case serve(key) do
      {:file, caminho} -> {:ok, fun.(caminho)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Bytes livres no volume dos uploads.

  Existe para a galeria recusar arquivo novo antes de o disco encher: falhar
  com mensagem clara é melhor do que estourar ENOSPC no meio de um upload.
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
  Caminho absoluto de uma chave NESTE adapter.

  Fora do behaviour de propósito: só faz sentido no disco. Testes usam para
  afirmar presença física; código de domínio deve passar por `serve/1` ou
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

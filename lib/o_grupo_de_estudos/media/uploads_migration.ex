defmodule OGrupoDeEstudos.Media.UploadsMigration do
  @moduledoc """
  Move from the local volume to the object port, in two halves:

  1. copies each disk file to `Media.ObjectStorage`, under the relative key
     (the same one the disk adapter uses);
  2. rewrites the stored public URLs in the database (`/uploads/...` becomes the
     provider public URL). Private keys (gallery) do not change: they have been
     relative from the start.

  Not a migration on purpose: a migration only changes schema, a backfill runs
  outside (project rule). In production:

      bin/o_grupo_de_estudos eval "OGrupoDeEstudos.Media.UploadsMigration.run()"

  Idempotent: a file already copied is overwritten with the same content, and a
  URL already rewritten no longer starts with `/uploads/`, so it drops out of the
  filter.

  Touches the Accounts and Workshops schemas on purpose, like `Admin.Backup`: an
  operations module sweeps what exists, it does not go through the domain API.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram}

  @prefixo_publico "/uploads/"

  @doc "Runs the whole migration and returns a summary of what happened."
  @spec run(String.t()) :: %{
          arquivos: non_neg_integer(),
          falhas: list(),
          reescritos: non_neg_integer()
        }
  def run(source_dir \\ default_dir()) do
    {arquivos, falhas} = copiar_tudo(source_dir)
    # Rewriting the URL of an object that failed to upload would leave an avatar
    # pointing at nothing, so any copy failure leaves the database alone. The next
    # run, with the copies healthy, completes the rewrite.
    reescritos = if falhas == [], do: reescrever_urls(), else: 0

    Logger.info(
      "[UploadsMigration] #{arquivos} arquivos copiados, #{reescritos} URLs reescritas, " <>
        "#{length(falhas)} falhas"
    )

    %{arquivos: arquivos, falhas: falhas, reescritos: reescritos}
  end

  defp copiar_tudo(dir) do
    {oks, falhas} = Enum.reduce(arquivos_relativos(dir), {0, []}, &copiar(dir, &1, &2))
    {oks, Enum.reverse(falhas)}
  end

  defp copiar(dir, chave, {oks, falhas}) do
    case ObjectStorage.put(chave, Path.join(dir, chave)) do
      :ok ->
        {oks + 1, falhas}

      {:error, motivo} ->
        Logger.warning("[UploadsMigration] falhou #{chave}: #{inspect(motivo)}")
        {oks, [{chave, motivo} | falhas]}
    end
  end

  defp arquivos_relativos(dir) do
    dir
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
  end

  defp reescrever_urls do
    {:ok, total} =
      Repo.transaction(fn ->
        reescrever(User, :avatar_path) +
          reescrever(Workshop, :flyer_path) +
          reescrever(WorkshopProgram, :flyer_path)
      end)

    total
  end

  defp reescrever(schema, campo) do
    from(r in schema,
      where: like(field(r, ^campo), ^"#{@prefixo_publico}%"),
      select: {r.id, field(r, ^campo)}
    )
    |> Repo.stream()
    |> Enum.reduce(0, fn linha, n -> n + trocar_url(schema, campo, linha) end)
  end

  defp trocar_url(schema, campo, {id, url}) do
    nova = url |> String.replace_prefix(@prefixo_publico, "") |> ObjectStorage.public_url()
    {1, _} = Repo.update_all(from(r in schema, where: r.id == ^id), set: [{campo, nova}])
    1
  end

  defp default_dir do
    Application.get_env(:o_grupo_de_estudos, :uploads_path, "/app/uploads")
  end
end

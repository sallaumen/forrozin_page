defmodule OGrupoDeEstudos.Media.UploadsMigration do
  @moduledoc """
  Mudança do volume local para a porta de objetos, em duas metades:

  1. copia cada arquivo do disco para `Media.ObjectStorage`, com a chave
     relativa (que é a mesma usada pelo adapter de disco);
  2. reescreve no banco as URLs públicas gravadas (`/uploads/...` vira a URL
     pública do provider). Chaves privadas (galeria) não mudam: já são
     relativas desde o começo.

  Não é migration de propósito: migration só muda schema, backfill roda por
  fora (regra do projeto). Em produção:

      bin/o_grupo_de_estudos eval "OGrupoDeEstudos.Media.UploadsMigration.run()"

  Idempotente: arquivo já copiado é sobrescrito com o mesmo conteúdo, e URL
  já reescrita não começa mais com `/uploads/`, então sai do filtro.

  Toca schema de Accounts e Workshops de propósito, como o `Admin.Backup`:
  módulo de operação varre o que existe, não passa pela API de domínio.
  """

  import Ecto.Query, only: [from: 2]

  require Logger

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram}

  @prefixo_publico "/uploads/"

  @doc "Roda a migração inteira e devolve o resumo do que aconteceu."
  @spec run(String.t()) :: %{
          arquivos: non_neg_integer(),
          falhas: list(),
          reescritos: non_neg_integer()
        }
  def run(source_dir \\ default_dir()) do
    {arquivos, falhas} = copiar_tudo(source_dir)
    reescritos = reescrever_urls()

    Logger.info(
      "[UploadsMigration] #{arquivos} arquivos copiados, #{reescritos} URLs reescritas, " <>
        "#{length(falhas)} falhas"
    )

    %{arquivos: arquivos, falhas: falhas, reescritos: reescritos}
  end

  # ── Arquivos ─────────────────────────────────────────────────────────

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

  # ── URLs no banco ────────────────────────────────────────────────────

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

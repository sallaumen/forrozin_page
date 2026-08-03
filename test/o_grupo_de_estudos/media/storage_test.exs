defmodule OGrupoDeEstudos.Media.StorageTest do
  @moduledoc """
  O serviço de mídia: política de nomes + processamento de imagem.

  Os bytes em si moram atrás da porta `Media.ObjectStorage`. Aqui mora o que
  NÃO muda quando o provider muda: como um avatar se chama, que um flyer é
  redimensionado, que chave privada é aleatória.
  """

  # async: false — troca :uploads_path, que é config global.
  use ExUnit.Case, async: false

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.Storage

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "storage_svc_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    anterior = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case anterior do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        valor -> Application.put_env(:o_grupo_de_estudos, :uploads_path, valor)
      end

      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "origem.png")
    File.write!(origem, @png)

    %{dir: dir, origem: origem}
  end

  describe "save_avatar/3" do
    test "guarda com o id no nome e devolve a URL pública", ctx do
      assert {:ok, url} = Storage.save_avatar("u1", ctx.origem, ".png")

      assert url =~ ~r|^/uploads/avatars/u1_\d+\.png$|
      assert ObjectStorage.exists?(String.replace_prefix(url, "/uploads/", ""))
    end

    test "trocar o avatar apaga a versão anterior", ctx do
      {:ok, url1} = Storage.save_avatar("u1", ctx.origem, ".png")
      # O nome carrega timestamp em segundos; sem esperar, seria o mesmo nome.
      Process.sleep(1100)
      File.write!(ctx.origem, @png)
      {:ok, url2} = Storage.save_avatar("u1", ctx.origem, ".png")

      assert url1 != url2
      refute ObjectStorage.exists?(String.replace_prefix(url1, "/uploads/", ""))
      assert ObjectStorage.exists?(String.replace_prefix(url2, "/uploads/", ""))
    end

    test "avatares de outra pessoa ficam em paz", ctx do
      {:ok, da_outra} = Storage.save_avatar("u2", ctx.origem, ".png")
      File.write!(ctx.origem, @png)
      {:ok, _} = Storage.save_avatar("u1", ctx.origem, ".png")

      assert ObjectStorage.exists?(String.replace_prefix(da_outra, "/uploads/", ""))
    end
  end

  describe "save_image/3" do
    test "flyer sai com chave aleatória, sem nada previsível no nome", ctx do
      assert {:ok, url} = Storage.save_image("flyers", ctx.origem, ".png")

      assert url =~ ~r|^/uploads/flyers/[A-Za-z0-9]+\.png$|
      refute url =~ "origem"
    end

    test "delete_image/1 apaga pela URL pública", ctx do
      {:ok, url} = Storage.save_image("flyers", ctx.origem, ".png")

      assert :ok = Storage.delete_image(url)
      refute ObjectStorage.exists?(String.replace_prefix(url, "/uploads/", ""))
    end

    test "delete_image/1 com URL de fora não faz nada", _ctx do
      assert :ok = Storage.delete_image("https://outro-site.com/x.png")
    end
  end

  describe "arquivos privados" do
    test "put_private/3 devolve chave opaca, nunca URL", ctx do
      assert {:ok, chave} = Storage.put_private("workshop_media", ctx.origem, ".mp4")

      assert chave =~ ~r|^workshop_media/[A-Za-z0-9]+\.mp4$|
      assert ObjectStorage.exists?(chave)
    end

    test "serve_private/1 entrega o arquivo para o send_file do controller", ctx do
      {:ok, chave} = Storage.put_private("workshop_media", ctx.origem, ".mp4")

      assert {:file, caminho} = Storage.serve_private(chave)
      assert File.read!(caminho) == @png
    end

    test "serve_private/1 de chave sem objeto devolve not_found", _ctx do
      assert {:error, :not_found} = Storage.serve_private("workshop_media/sumiu.mp4")
    end

    test "with_private_file/2 dá um caminho local para o ffmpeg ler", ctx do
      {:ok, chave} = Storage.put_private("workshop_media", ctx.origem, ".mov")

      assert {:ok, tamanho} = Storage.with_private_file(chave, fn c -> File.stat!(c).size end)
      assert tamanho == byte_size(@png)
    end

    test "delete_private/1 apaga e é silencioso na segunda vez", ctx do
      {:ok, chave} = Storage.put_private("workshop_media", ctx.origem, ".mp4")

      assert :ok = Storage.delete_private(chave)
      assert :ok = Storage.delete_private(chave)
      refute ObjectStorage.exists?(chave)
    end
  end

  describe "free_bytes/0" do
    test "responde com número ou :unknown, nunca estoura" do
      assert is_integer(Storage.free_bytes()) or Storage.free_bytes() == :unknown
    end
  end
end

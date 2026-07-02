defmodule OGrupoDeEstudosWeb.Plugs.UploadsStaticTest do
  # async: false — o teste troca :uploads_path no app env global.
  use OGrupoDeEstudosWeb.ConnCase, async: false

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "uploads_static_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "avatars"))
    File.write!(Path.join(dir, "avatars/foto.png"), "png-fake")

    previous = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        value -> Application.put_env(:o_grupo_de_estudos, :uploads_path, value)
      end

      File.rm_rf!(dir)
    end)

    :ok
  end

  test "serves an existing upload", %{conn: conn} do
    conn = get(conn, "/uploads/avatars/foto.png")

    assert response(conn, 200) == "png-fake"
  end

  test "missing upload falls through to 404", %{conn: conn} do
    conn = get(conn, "/uploads/avatars/nao-existe.png")

    assert conn.status == 404
  end
end

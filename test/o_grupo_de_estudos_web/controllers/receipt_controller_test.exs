defmodule OGrupoDeEstudosWeb.ReceiptControllerTest do
  @moduledoc """
  Who gets past the door of a receipt file.

  A receipt carries bank data, so anything that is not an explicit yes answers
  404: saying "no permission" would already confirm the file is there.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: false

  alias OGrupoDeEstudos.Workshops

  @png Base.decode64!(
         "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
       )

  setup do
    dir = Path.join(System.tmp_dir!(), "receipt_web_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    previous = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        value -> Application.put_env(:o_grupo_de_estudos, :uploads_path, value)
      end

      File.rm_rf!(dir)
    end)

    source = Path.join(dir, "comprovante.png")
    File.write!(source, @png)

    organizer = insert(:user, is_teacher: true)
    student = insert(:user)
    workshop = insert(:workshop, organizer: organizer, price_cents: 5000)
    {:ok, _} = Workshops.enroll(workshop, student)

    upload = %{tmp_path: source, content_type: "image/png", byte_size: byte_size(@png)}
    {:ok, enrollment} = Workshops.send_workshop_receipt(workshop, student, upload)

    %{
      organizer: organizer,
      student: student,
      workshop: workshop,
      enrollment: enrollment,
      upload: upload
    }
  end

  describe "the workshop receipt" do
    test "whoever sent it opens their own", ctx do
      conn = get(log_in_user(ctx.conn, ctx.student), ~p"/workshop-receipts/#{ctx.enrollment.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/png"]
    end

    test "whoever runs the workshop opens it", ctx do
      conn =
        get(log_in_user(ctx.conn, ctx.organizer), ~p"/workshop-receipts/#{ctx.enrollment.id}")

      assert conn.status == 200
    end

    test "it never lands in a shared cache", ctx do
      conn = get(log_in_user(ctx.conn, ctx.student), ~p"/workshop-receipts/#{ctx.enrollment.id}")

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "another person in the same class gets nothing", ctx do
      other = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, other)

      conn = get(log_in_user(ctx.conn, other), ~p"/workshop-receipts/#{ctx.enrollment.id}")

      assert conn.status == 404
    end

    test "a visitor with no account gets nothing", ctx do
      conn = get(ctx.conn, ~p"/workshop-receipts/#{ctx.enrollment.id}")

      assert conn.status == 404
    end

    test "an id that is not even a uuid does not crash", ctx do
      conn = get(log_in_user(ctx.conn, ctx.organizer), ~p"/workshop-receipts/nao-e-uuid")

      assert conn.status == 404
    end

    test "an enrollment with no receipt gets nothing", ctx do
      {:ok, cleared} =
        Workshops.remove_workshop_receipt(ctx.workshop, ctx.student, ctx.enrollment.id)

      conn = get(log_in_user(ctx.conn, ctx.student), ~p"/workshop-receipts/#{cleared.id}")

      assert conn.status == 404
    end
  end

  describe "the package receipt" do
    setup ctx do
      program = insert(:workshop_program, owner: ctx.organizer, price_cents: 12_000)
      _covered = insert(:workshop, organizer: ctx.organizer, program: program)
      buyer = insert(:user)
      {:ok, _} = Workshops.enroll_in_package(program, buyer)
      {:ok, package} = Workshops.send_program_receipt(program, buyer, ctx.upload)

      Map.merge(ctx, %{program: program, buyer: buyer, package: package})
    end

    test "whoever bought it opens their own", ctx do
      conn = get(log_in_user(ctx.conn, ctx.buyer), ~p"/program-receipts/#{ctx.package.id}")

      assert conn.status == 200
    end

    test "whoever owns the program opens it", ctx do
      conn = get(log_in_user(ctx.conn, ctx.organizer), ~p"/program-receipts/#{ctx.package.id}")

      assert conn.status == 200
    end

    test "anyone else gets nothing", ctx do
      conn = get(log_in_user(ctx.conn, insert(:user)), ~p"/program-receipts/#{ctx.package.id}")

      assert conn.status == 404
    end
  end

  describe "a content type forged by the sender's browser" do
    test "an svg never even reaches the storage, so it cannot be served back", ctx do
      forged = %{ctx.upload | content_type: "image/svg+xml"}

      assert {:error, :unsupported_type} =
               Workshops.send_workshop_receipt(ctx.workshop, ctx.student, forged)
    end
  end
end

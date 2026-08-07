defmodule OGrupoDeEstudosWeb.CollectionSectionEditTest do
  @moduledoc """
  Editing a family from inside the family, which is where it reads.

  There was a form for this, in a slide-over panel, reachable from nowhere: no
  button in the whole app fired `open_section`. The test that covered it sent
  the event by hand, so it stayed green for months while the admin had no way
  in. Every test here goes through a control a person can see and press.

  The note is the other half. Eight of the twenty-one families carry one and it
  rendered only inside that unreachable panel, so it was writing nobody read.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Encyclopedia

  setup do
    category = insert(:category, name: "bases", label: "Bases", color: "#8a5a2b")

    section =
      insert(:section,
        category: category,
        title: "Bases",
        code: "B",
        position: 1,
        description: "O chão de tudo.",
        note: "Comece pelo peso no pé de trás."
      )

    insert(:step, section: section, category: category, code: "BF", name: "Base frontal")

    %{category: category, section: section}
  end

  defp open_family(conn, user, section) do
    live(log_in_user(conn, user), ~p"/collection?section=#{section.id}")
  end

  defp editing_family(conn, section) do
    {:ok, lv, _html} = open_family(conn, insert(:admin), section)
    render_click(lv, "toggle_edit_mode", %{})
    lv
  end

  defp pencil(field), do: ~s{button[phx-click="edit_field"][phx-value-field="#{field}"]}

  describe "the note the database was keeping to itself" do
    test "reads inside the family, for whoever is studying", ctx do
      {:ok, _lv, html} = open_family(ctx.conn, insert(:user), ctx.section)

      assert html =~ "Comece pelo peso no pé de trás."
    end

    test "a family without one opens no empty box", ctx do
      quiet = insert(:section, category: ctx.category, title: "Travas", position: 2, note: nil)
      insert(:step, section: quiet, category: ctx.category, code: "TR-F", name: "Trava frontal")

      {:ok, _lv, html} = open_family(ctx.conn, insert(:user), quiet)

      refute html =~ "collection-family-note"
    end
  end

  describe "who gets a pencil" do
    test "nobody, until the admin turns editing on", ctx do
      {:ok, lv, _html} = open_family(ctx.conn, insert(:admin), ctx.section)

      refute has_element?(lv, pencil("title"))
    end

    test "the four fields a family is made of, once it is on", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      for field <- ~w(title category_id description note) do
        assert has_element?(lv, pencil(field)), "faltou o lápis de #{field}"
      end
    end

    test "never whoever is studying, even with the event sent by hand", ctx do
      {:ok, lv, _html} = open_family(ctx.conn, insert(:user), ctx.section)

      render_click(lv, "toggle_edit_mode", %{})

      refute has_element?(lv, pencil("title"))
    end
  end

  describe "changing a family where it reads" do
    test "the new title holds in the family and back in the mosaic", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      render_click(lv, "edit_field", %{"field" => "title"})
      assert render_submit(lv, "save_field", %{"value" => "Bases e apoios"}) =~ "Bases e apoios"

      {:ok, _mosaic, html} = live(log_in_user(ctx.conn, insert(:user)), ~p"/collection")
      assert html =~ "Bases e apoios"
    end

    test "the note reaches whoever is studying", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      render_click(lv, "edit_field", %{"field" => "note"})
      render_submit(lv, "save_field", %{"value" => "O peso mora no pé de trás."})

      {:ok, _lv, html} = open_family(ctx.conn, insert(:user), ctx.section)
      assert html =~ "O peso mora no pé de trás."
    end

    test "an emptied description becomes absent, not an empty string", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      render_click(lv, "edit_field", %{"field" => "description"})
      render_submit(lv, "save_field", %{"value" => "   "})

      assert Encyclopedia.get_section_by(id: ctx.section.id).description == nil
    end

    test "a category whose name repeats the family still reads under the pencil", ctx do
      echo = insert(:category, name: "caminhadas", label: "Caminhadas", color: "#5a7a2b")
      family = insert(:section, category: echo, title: "Caminhadas", position: 3)
      insert(:step, section: family, category: echo, code: "CA-F", name: "Caminhada frontal")

      {:ok, _reading, html} = open_family(ctx.conn, insert(:user), family)
      refute html =~ "Caminhadas ·", "a linha repetiria o título logo acima dela"

      refute render(editing_family(ctx.conn, family)) =~ "sem categoria",
             "a família tem categoria; calar o nome não é o mesmo que não ter"
    end

    test "the category is picked from the ones that exist, not typed", ctx do
      other = insert(:category, name: "giros", label: "Giros", color: "#2e6f9f")
      lv = editing_family(ctx.conn, ctx.section)

      render_click(lv, "edit_field", %{"field" => "category_id"})

      assert has_element?(lv, ~s{select[name="value"] option[value="#{other.id}"]})
      assert render_submit(lv, "save_field", %{"value" => other.id}) =~ "Giros"
    end
  end

  describe "what a pencil may not write" do
    test "a field name the page never offered stays shut", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      render_click(lv, "edit_field", %{"field" => "position"})

      refute has_element?(lv, ~s{form[phx-submit="save_field"]})
    end

    test "a save with no field open writes nothing", ctx do
      lv = editing_family(ctx.conn, ctx.section)

      render_submit(lv, "save_field", %{"value" => "Bases roubadas"})

      assert Encyclopedia.get_section_by(id: ctx.section.id).title == "Bases"
    end

    test "whoever is studying cannot write by sending the events by hand", ctx do
      {:ok, lv, _html} = open_family(ctx.conn, insert(:user), ctx.section)

      render_click(lv, "edit_field", %{"field" => "title"})
      render_submit(lv, "save_field", %{"value" => "Bases roubadas"})

      assert Encyclopedia.get_section_by(id: ctx.section.id).title == "Bases"
    end
  end
end

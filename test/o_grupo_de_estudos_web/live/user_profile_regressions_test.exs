defmodule OGrupoDeEstudosWeb.UserProfileRegressionsTest do
  @moduledoc """
  Three things the profile did to whoever used it, none of them visible in a
  screenshot.

  The contributions tab took the whole LiveView down for anyone who had ever
  suggested an edit: the template matched `action` against strings after the
  column became an `Ecto.Enum`, so no clause matched and the process died. The
  follow button inside the followers panel wrote the follow to the database and
  then redrew itself as "Seguir", so the next tap silently undid it. And the
  sequences tab rendered an empty area with no sentence in it.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    %{owner: insert(:user), other: insert(:user)}
  end

  defp open(conn, viewer, profile),
    do: live(log_in_user(conn, viewer), ~p"/users/#{profile.username}")

  describe "the contributions tab" do
    test "survives a suggestion that was accepted", ctx do
      insert(:suggestion, user: ctx.owner, action: :edit_field, status: :approved)

      {:ok, lv, _html} = open(ctx.conn, ctx.owner, ctx.owner)
      html = render_patch(lv, ~p"/users/#{ctx.owner.username}?tab=contributions")

      assert html =~ "Edição de"
      assert html =~ "Aprovado", "o estado da sugestão é lido por gente, em português"
      refute html =~ "Approved"
    end

    test "survives a connection suggestion still waiting", ctx do
      insert(:suggestion,
        user: ctx.owner,
        action: :create_connection,
        status: :pending,
        new_value: "IV → SCSP"
      )

      {:ok, lv, _html} = open(ctx.conn, ctx.owner, ctx.owner)
      html = render_patch(lv, ~p"/users/#{ctx.owner.username}?tab=contributions")

      assert html =~ "Nova conexão"
      assert html =~ "Aguardando revisão"
    end

    test "survives a removal that was turned down", ctx do
      insert(:suggestion,
        user: ctx.owner,
        action: :remove_connection,
        status: :rejected,
        old_value: "IV → PI"
      )

      {:ok, lv, _html} = open(ctx.conn, ctx.owner, ctx.owner)
      html = render_patch(lv, ~p"/users/#{ctx.owner.username}?tab=contributions")

      assert html =~ "Remover conexão"
      assert html =~ "Rejeitado"
    end
  end

  describe "following someone from inside the followers panel" do
    test "the button says so, instead of offering to follow again", ctx do
      third = insert(:user)
      {:ok, _} = OGrupoDeEstudos.Engagement.toggle_follow(third.id, ctx.owner.id)

      {:ok, lv, _html} = open(ctx.conn, ctx.other, ctx.owner)
      render_click(lv, "toggle_followers_list", %{"tab" => "followers"})

      refute has_element?(lv, ~s{button[phx-value-user-id="#{third.id}"]}, "Seguindo")

      render_click(lv, "toggle_follow", %{"user-id" => third.id})

      assert has_element?(lv, ~s{button[phx-value-user-id="#{third.id}"]}, "Seguindo"),
             "o follow foi gravado; se o botão ainda diz Seguir, o próximo toque desfaz em silêncio"
    end
  end

  describe "the sequences tab with nothing in it" do
    test "says so instead of leaving the area blank", ctx do
      {:ok, lv, _html} = open(ctx.conn, ctx.other, ctx.owner)

      html = render_patch(lv, ~p"/users/#{ctx.owner.username}?tab=sequences")

      assert html =~ "nenhuma sequência",
             "aba vazia sem uma frase é indistinguível de tela quebrada"
    end
  end
end

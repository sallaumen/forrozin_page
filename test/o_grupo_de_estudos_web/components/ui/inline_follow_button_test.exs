defmodule OGrupoDeEstudosWeb.UI.InlineFollowButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.InlineFollowButton

  describe "inline_follow_button/1" do
    test "renders nothing when target is current user" do
      html =
        render_component(&InlineFollowButton.inline_follow_button/1, %{
          target_user_id: "user-1",
          current_user_id: "user-1",
          following_user_ids: MapSet.new()
        })

      refute html =~ "Seguir"
      refute html =~ "Seguindo"
    end

    test "renders Seguir when not following" do
      html =
        render_component(&InlineFollowButton.inline_follow_button/1, %{
          target_user_id: "user-2",
          current_user_id: "user-1",
          following_user_ids: MapSet.new()
        })

      assert html =~ "Seguir"
      refute html =~ "Seguindo"
    end

    test "renders Seguindo when already following" do
      html =
        render_component(&InlineFollowButton.inline_follow_button/1, %{
          target_user_id: "user-2",
          current_user_id: "user-1",
          following_user_ids: MapSet.new(["user-2"])
        })

      assert html =~ "Seguindo"
    end

    test "renders nothing when target_user_id is nil" do
      html =
        render_component(&InlineFollowButton.inline_follow_button/1, %{
          target_user_id: nil,
          current_user_id: "user-1",
          following_user_ids: MapSet.new()
        })

      refute html =~ "Seguir"
    end

    test "emits toggle_follow with phx-value-user-id" do
      html =
        render_component(&InlineFollowButton.inline_follow_button/1, %{
          target_user_id: "user-2",
          current_user_id: "user-1",
          following_user_ids: MapSet.new()
        })

      assert html =~ ~s(phx-click="toggle_follow")
      assert html =~ ~s(phx-value-user-id="user-2")
    end
  end
end

defmodule OGrupoDeEstudosWeb.Helpers.NotificationPresenterTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudosWeb.Helpers.NotificationPresenter, as: Presenter

  describe "actors_label/1" do
    test "single actor returns the name" do
      assert Presenter.actors_label(%{actors_data: [%{name: "Maria", username: "maria"}]}) ==
               "Maria"
    end

    test "falls back to username when name is nil" do
      assert Presenter.actors_label(%{actors_data: [%{name: nil, username: "maria"}]}) == "maria"
    end

    test "multiple actors append 'e mais N'" do
      actors = [
        %{name: "Maria", username: "m"},
        %{name: "Joao", username: "j"},
        %{name: "Ana", username: "a"}
      ]

      assert Presenter.actors_label(%{actors_data: actors}) == "Maria e mais 2"
    end

    test "empty actors return 'Alguém'" do
      assert Presenter.actors_label(%{actors_data: []}) == "Alguém"
    end
  end

  describe "action_text/1" do
    test "singular when count is 1" do
      assert Presenter.action_text(%{action: :liked_step, count: 1}) == " curtiu o passo"
    end

    test "plural when count is greater than 1" do
      assert Presenter.action_text(%{action: :liked_step, count: 3}) == " curtiram o passo"
    end

    test "follow pluralizes" do
      assert Presenter.action_text(%{action: :followed_user, count: 2}) ==
               " começaram a te seguir"
    end

    test "study actions ignore count" do
      assert Presenter.action_text(%{action: :study_request, count: 5}) ==
               " quer estudar com você"
    end

    test "unknown action falls back" do
      assert Presenter.action_text(%{action: "whatever", count: 1}) == " interagiu"
    end

    test "defaults to singular without a count key" do
      assert Presenter.action_text(%{action: :liked_step}) == " curtiu o passo"
    end
  end

  describe "notification_initial/1" do
    test "uppercases first letter of primary actor" do
      assert Presenter.notification_initial(%{actors_data: [%{name: "maria", username: "m"}]}) ==
               "M"
    end

    test "falls back to '?' when empty" do
      assert Presenter.notification_initial(%{actors_data: []}) == "?"
    end
  end
end

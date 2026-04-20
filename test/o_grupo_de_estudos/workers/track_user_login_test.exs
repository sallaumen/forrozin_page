defmodule OGrupoDeEstudos.Workers.TrackUserLoginTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Engagement.UserLoginEvent
  alias OGrupoDeEstudos.Workers.TrackUserLogin

  describe "perform/1" do
    test "stores a login event and updates the user's login timestamps" do
      user = insert(:user)
      occurred_at = ~N[2026-04-20 18:10:00]

      assert :ok =
               perform_job(TrackUserLogin, %{
                 "user_id" => user.id,
                 "method" => "password",
                 "device_type" => "mobile",
                 "browser" => "Chrome",
                 "is_pwa" => false,
                 "user_agent" => "Mozilla/5.0 (iPhone) AppleWebKit Chrome",
                 "occurred_at" => NaiveDateTime.to_iso8601(occurred_at)
               })

      event = Repo.get_by!(UserLoginEvent, user_id: user.id)
      user = Accounts.get_user_by_id(user.id)

      assert event.method == "password"
      assert event.device_type == "mobile"
      assert event.browser == "Chrome"
      refute event.is_pwa
      assert event.user_agent == "Mozilla/5.0 (iPhone) AppleWebKit Chrome"
      assert event.occurred_at == occurred_at
      assert user.last_login_at == occurred_at
      assert user.last_seen_at == occurred_at
    end

    test "discards jobs for users that no longer exist" do
      assert {:discard, :user_not_found} =
               perform_job(TrackUserLogin, %{
                 "user_id" => Ecto.UUID.generate(),
                 "method" => "password",
                 "occurred_at" => "2026-04-20T18:10:00"
               })
    end
  end
end

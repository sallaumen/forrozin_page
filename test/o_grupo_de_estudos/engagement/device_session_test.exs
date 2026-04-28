defmodule OGrupoDeEstudos.Engagement.DeviceSessionTest do
  use OGrupoDeEstudos.DataCase, async: true

  import Ecto.Query
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.DeviceSession
  alias OGrupoDeEstudos.Repo

  describe "changeset/2 — valid data" do
    test "creates a valid mobile session" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{
          user_id: user.id,
          device_type: "mobile",
          browser: "Chrome",
          is_pwa: false,
          user_agent: "Mozilla/5.0 (Linux; Android 10)"
        })
        |> Repo.insert()

      assert session.device_type == "mobile"
      assert session.browser == "Chrome"
      refute session.is_pwa
      assert session.user_agent == "Mozilla/5.0 (Linux; Android 10)"
      assert session.user_id == user.id
    end

    test "creates a valid desktop session with is_pwa: true" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{
          user_id: user.id,
          device_type: "desktop",
          browser: "Firefox",
          is_pwa: true
        })
        |> Repo.insert()

      assert session.device_type == "desktop"
      assert session.is_pwa
    end

    test "creates a valid tablet session" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{
          user_id: user.id,
          device_type: "tablet"
        })
        |> Repo.insert()

      assert session.device_type == "tablet"
    end

    test "browser and user_agent are optional" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{user_id: user.id, device_type: "mobile"})
        |> Repo.insert()

      assert is_nil(session.browser)
      assert is_nil(session.user_agent)
    end

    test "is_pwa defaults to false when not provided" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{user_id: user.id, device_type: "desktop"})
        |> Repo.insert()

      refute session.is_pwa
    end
  end

  describe "changeset/2 — validation errors" do
    test "requires device_type" do
      user = insert(:user)
      changeset = DeviceSession.changeset(%DeviceSession{}, %{user_id: user.id})
      refute changeset.valid?
      assert errors_on(changeset).device_type
    end

    test "requires user_id" do
      changeset = DeviceSession.changeset(%DeviceSession{}, %{device_type: "mobile"})
      refute changeset.valid?
      assert errors_on(changeset).user_id
    end

    test "rejects unknown device_type" do
      user = insert(:user)

      changeset =
        DeviceSession.changeset(%DeviceSession{}, %{
          user_id: user.id,
          device_type: "smartwatch"
        })

      refute changeset.valid?
      assert errors_on(changeset).device_type
    end

    test "rejects empty changeset — both required fields missing" do
      changeset = DeviceSession.changeset(%DeviceSession{}, %{})
      refute changeset.valid?
      assert errors_on(changeset).device_type
      assert errors_on(changeset).user_id
    end
  end

  describe "persistence" do
    test "inserted_at is set automatically on insert" do
      user = insert(:user)

      {:ok, session} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{user_id: user.id, device_type: "mobile"})
        |> Repo.insert()

      assert session.inserted_at != nil
    end

    test "multiple sessions can be created for the same user" do
      user = insert(:user)

      {:ok, _s1} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{user_id: user.id, device_type: "mobile"})
        |> Repo.insert()

      {:ok, _s2} =
        %DeviceSession{}
        |> DeviceSession.changeset(%{user_id: user.id, device_type: "desktop"})
        |> Repo.insert()

      count =
        Repo.aggregate(
          from(ds in DeviceSession, where: ds.user_id == ^user.id),
          :count
        )

      assert count == 2
    end
  end
end

defmodule Forrozin.Engagement.ProfileCommentQueryTest do
  use Forrozin.DataCase, async: true

  import Forrozin.Factory

  alias Forrozin.Engagement.ProfileCommentQuery

  setup do
    profile = insert(:user)
    author = insert(:user)
    %{profile: profile, author: author}
  end

  describe "list_by/1 — profile_id filter" do
    test "returns only comments for the given profile", %{profile: profile, author: author} do
      other_profile = insert(:user)
      insert(:profile_comment, profile: profile, author: author)
      insert(:profile_comment, profile: other_profile, author: author)

      results = ProfileCommentQuery.list_by(profile_id: profile.id)
      assert length(results) == 1
      assert hd(results).profile_id == profile.id
    end

    test "returns empty list when profile has no comments", %{profile: profile} do
      assert [] = ProfileCommentQuery.list_by(profile_id: profile.id)
    end
  end

  describe "list_by/1 — author_id filter" do
    test "returns only comments by the given author", %{profile: profile, author: author} do
      other_author = insert(:user)
      insert(:profile_comment, profile: profile, author: author)
      insert(:profile_comment, profile: profile, author: other_author)

      results = ProfileCommentQuery.list_by(author_id: author.id)
      assert length(results) == 1
      assert hd(results).author_id == author.id
    end
  end

  describe "list_by/1 — include_deleted filter" do
    test "excludes soft-deleted comments by default", %{profile: profile, author: author} do
      active = insert(:profile_comment, profile: profile, author: author)

      deleted =
        insert(:profile_comment,
          profile: profile,
          author: author,
          deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        )

      results = ProfileCommentQuery.list_by(profile_id: profile.id)
      ids = Enum.map(results, & &1.id)

      assert active.id in ids
      refute deleted.id in ids
    end

    test "includes soft-deleted comments when include_deleted: true", %{
      profile: profile,
      author: author
    } do
      deleted =
        insert(:profile_comment,
          profile: profile,
          author: author,
          deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        )

      results = ProfileCommentQuery.list_by(profile_id: profile.id, include_deleted: true)
      ids = Enum.map(results, & &1.id)

      assert deleted.id in ids
    end
  end

  describe "list_by/1 — preload" do
    test "preloads author association when requested", %{profile: profile, author: author} do
      insert(:profile_comment, profile: profile, author: author)

      [comment] = ProfileCommentQuery.list_by(profile_id: profile.id, preload: [:author])
      assert %Forrozin.Accounts.User{} = comment.author
      assert comment.author.id == author.id
    end

    test "does not preload when not requested", %{profile: profile, author: author} do
      insert(:profile_comment, profile: profile, author: author)

      [comment] = ProfileCommentQuery.list_by(profile_id: profile.id)
      assert %Ecto.Association.NotLoaded{} = comment.author
    end
  end

  describe "list_by/1 — order_by" do
    test "returns newest comments first by default", %{profile: profile, author: author} do
      first = insert(:profile_comment, profile: profile, author: author)

      # Ensure a distinct inserted_at by advancing time
      second =
        insert(:profile_comment,
          profile: profile,
          author: author,
          inserted_at:
            NaiveDateTime.utc_now()
            |> NaiveDateTime.add(60, :second)
            |> NaiveDateTime.truncate(:second)
        )

      results = ProfileCommentQuery.list_by(profile_id: profile.id)
      ids = Enum.map(results, & &1.id)

      assert ids == [second.id, first.id]
    end
  end
end

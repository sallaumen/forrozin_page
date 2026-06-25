defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceLibraryTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia.Category
  alias OGrupoDeEstudosWeb.GraphVisual.SequenceLibrary

  # ── helpers ───────────────────────────────────────────────────────────

  @not_loaded %Ecto.Association.NotLoaded{
    __field__: :assoc,
    __owner__: nil,
    __cardinality__: :one
  }

  defp seq(opts) do
    %{
      id: Keyword.get(opts, :id, 1),
      name: Keyword.get(opts, :name, "Seq"),
      description: Keyword.get(opts, :description, nil),
      public: Keyword.get(opts, :public, true),
      inserted_at: Keyword.get(opts, :inserted_at, nil),
      user: Keyword.get(opts, :user, @not_loaded),
      sequence_steps: Keyword.get(opts, :steps, [])
    }
  end

  defp step(opts) do
    %{
      step: %{
        code: Keyword.get(opts, :code, "X"),
        name: Keyword.get(opts, :name, "Step"),
        category: Keyword.get(opts, :category, @not_loaded)
      }
    }
  end

  defp ms(ids), do: MapSet.new(ids)

  # ── sequence_library_rank/3 ───────────────────────────────────────────

  describe "sequence_library_rank/3" do
    test "owned AND favorite ranks 0 (highest)" do
      assert SequenceLibrary.sequence_library_rank(seq(id: 1), ms([1]), ms([1])) == 0
    end

    test "owned only ranks 1" do
      assert SequenceLibrary.sequence_library_rank(seq(id: 1), ms([1]), ms([])) == 1
    end

    test "favorite only ranks 2" do
      assert SequenceLibrary.sequence_library_rank(seq(id: 1), ms([]), ms([1])) == 2
    end

    test "neither owned nor favorite ranks 3 (lowest)" do
      assert SequenceLibrary.sequence_library_rank(seq(id: 1), ms([]), ms([])) == 3
    end

    test "membership is keyed strictly by sequence.id" do
      assert SequenceLibrary.sequence_library_rank(seq(id: 99), ms([1, 2, 3]), ms([1, 2, 3])) == 3
    end
  end

  # ── normalize_sequence_date/1 ─────────────────────────────────────────

  describe "normalize_sequence_date/1" do
    test "nil normalizes to 0" do
      assert SequenceLibrary.normalize_sequence_date(nil) == 0
    end

    test "epoch maps to 0 (ties with nil)" do
      assert SequenceLibrary.normalize_sequence_date(~N[1970-01-01 00:00:00]) == 0
    end

    test "a NaiveDateTime returns the negated epoch-second diff" do
      date = ~N[2026-06-25 12:00:00]
      expected = -NaiveDateTime.diff(date, ~N[1970-01-01 00:00:00])
      assert SequenceLibrary.normalize_sequence_date(date) == expected
    end

    test "newer dates sort before older (more negative key)" do
      newer = SequenceLibrary.normalize_sequence_date(~N[2026-01-01 00:00:00])
      older = SequenceLibrary.normalize_sequence_date(~N[2020-01-01 00:00:00])
      assert newer < older
    end
  end

  # ── sequence_matches_origin_filter?/4 ─────────────────────────────────

  describe "sequence_matches_origin_filter?/4" do
    test "favorites matches only sequences in favorite_ids" do
      assert SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 1),
               "favorites",
               ms([]),
               ms([1])
             )

      refute SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 2),
               "favorites",
               ms([]),
               ms([1])
             )
    end

    test "community matches public sequences not owned" do
      assert SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 1, public: true),
               "community",
               ms([]),
               ms([])
             )
    end

    test "community excludes owned sequences even if public" do
      refute SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 1, public: true),
               "community",
               ms([1]),
               ms([])
             )
    end

    test "community excludes private sequences even if not owned" do
      refute SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 1, public: false),
               "community",
               ms([]),
               ms([])
             )
    end

    test "any other origin matches everything via catch-all" do
      assert SequenceLibrary.sequence_matches_origin_filter?(
               seq(id: 1, public: false),
               "all",
               ms([]),
               ms([])
             )

      assert SequenceLibrary.sequence_matches_origin_filter?(seq(id: 1), "saved", ms([]), ms([]))
    end
  end

  # ── sequence_matches_search?/2 (search arg is pre-normalized) ──────────

  describe "sequence_matches_search?/2" do
    test "matches on sequence name (text already normalized internally)" do
      assert SequenceLibrary.sequence_matches_search?(seq(name: "Inversão Básica"), "inversao")
    end

    test "matches on description" do
      assert SequenceLibrary.sequence_matches_search?(
               seq(name: "X", description: "passo de transição suave"),
               "transicao"
             )
    end

    test "matches on author username only when user assoc is loaded" do
      assert SequenceLibrary.sequence_matches_search?(
               seq(name: "X", user: %User{username: "Tata"}),
               "tata"
             )
    end

    test "username excluded when user assoc is unloaded" do
      refute SequenceLibrary.sequence_matches_search?(seq(name: "X", user: @not_loaded), "tata")
    end

    test "loaded-but-nil user does not crash (guard short-circuits on nil)" do
      # assoc_loaded?(nil) is true, so only the `&& sequence.user` half prevents a
      # nil deref; this pins that guard half.
      refute SequenceLibrary.sequence_matches_search?(seq(name: "X", user: nil), "tata")
    end

    test "matches on a step code" do
      assert SequenceLibrary.sequence_matches_search?(
               seq(name: "X", steps: [step(code: "SCSP")]),
               "scsp"
             )
    end

    test "matches on a step name (accent-insensitive)" do
      assert SequenceLibrary.sequence_matches_search?(
               seq(name: "X", steps: [step(code: "IV", name: "Inversão")]),
               "inversao"
             )
    end

    test "matches on a loaded step category name/label" do
      step = step(code: "BF", name: "Base", category: %Category{name: "basico", label: "Básico"})
      assert SequenceLibrary.sequence_matches_search?(seq(name: "X", steps: [step]), "basico")
    end

    test "category fields excluded when category assoc unloaded" do
      step = step(code: "BF", name: "Base", category: @not_loaded)
      refute SequenceLibrary.sequence_matches_search?(seq(name: "X", steps: [step]), "basico")
    end

    test "no match across any field returns false" do
      refute SequenceLibrary.sequence_matches_search?(
               seq(name: "Base", description: "simples"),
               "zzz"
             )
    end
  end

  # ── sequence_has_category?/2 ──────────────────────────────────────────

  describe "sequence_has_category?/2" do
    test "true when any loaded step category name equals the filter" do
      steps = [
        step(category: %Category{name: "basico"}),
        step(category: %Category{name: "giros"})
      ]

      assert SequenceLibrary.sequence_has_category?(seq(steps: steps), "giros")
    end

    test "false when no step has the filtered category" do
      steps = [
        step(category: %Category{name: "basico"}),
        step(category: %Category{name: "giros"})
      ]

      refute SequenceLibrary.sequence_has_category?(seq(steps: steps), "footwork")
    end

    test "false when category assoc is not loaded" do
      refute SequenceLibrary.sequence_has_category?(
               seq(steps: [step(category: @not_loaded)]),
               "basico"
             )
    end

    test "false when a step category is nil" do
      refute SequenceLibrary.sequence_has_category?(seq(steps: [step(category: nil)]), "basico")
    end

    test "false for empty steps" do
      refute SequenceLibrary.sequence_has_category?(seq(steps: []), "basico")
    end
  end

  # ── filter_sequence_library/6 ─────────────────────────────────────────

  describe "filter_sequence_library/6" do
    test "empty search and all/all filters return all in order" do
      a = seq(id: 1, name: "A")
      b = seq(id: 2, name: "B")

      assert SequenceLibrary.filter_sequence_library([a, b], "", "all", "all", ms([]), ms([])) ==
               [a, b]
    end

    test "raw accented search is normalized internally" do
      s = seq(id: 1, name: "Inversão")

      assert SequenceLibrary.filter_sequence_library(
               [s],
               "INVERSÃO",
               "all",
               "all",
               ms([]),
               ms([])
             ) == [s]
    end

    test "origin and category filters compose with AND" do
      a = seq(id: 1, public: true, steps: [step(category: %Category{name: "giros"})])
      b = seq(id: 2, public: true, steps: [step(category: %Category{name: "basico"})])

      result =
        SequenceLibrary.filter_sequence_library([a, b], "", "community", "giros", ms([]), ms([]))

      assert result == [a]
    end

    test "favorites origin narrows to favorite_ids" do
      a = seq(id: 1, public: true)
      b = seq(id: 2, public: true)

      assert SequenceLibrary.filter_sequence_library(
               [a, b],
               "",
               "favorites",
               "all",
               ms([]),
               ms([2])
             ) == [b]
    end

    test "search excludes non-matching sequences" do
      a = seq(id: 1, name: "Base")
      b = seq(id: 2, name: "Giro")

      assert SequenceLibrary.filter_sequence_library([a, b], "giro", "all", "all", ms([]), ms([])) ==
               [b]
    end

    test "empty input returns empty" do
      assert SequenceLibrary.filter_sequence_library(
               [],
               "x",
               "favorites",
               "giros",
               ms([1]),
               ms([1])
             ) == []
    end

    test "combined search + favorites + category narrows to one" do
      a =
        seq(
          id: 1,
          public: true,
          name: "Base Lenta",
          steps: [step(category: %Category{name: "basico"})]
        )

      b =
        seq(
          id: 2,
          public: true,
          name: "Giro Triplo",
          steps: [step(category: %Category{name: "giros"})]
        )

      c =
        seq(
          id: 3,
          public: true,
          name: "Base Rapida",
          steps: [step(category: %Category{name: "basico"})]
        )

      result =
        SequenceLibrary.filter_sequence_library(
          [a, b, c],
          "base",
          "favorites",
          "basico",
          ms([]),
          ms([1, 2])
        )

      assert result == [a]
    end
  end
end

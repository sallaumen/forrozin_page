defmodule OGrupoDeEstudos.Metadata do
  @moduledoc """
  Generic key-value metadata store. Avoids adding columns to existing
  tables for small features that just need a counter or flag.

  Usage:
      Metadata.get("password_reset_count", "user", user_id)
      Metadata.set("password_reset_count", "user", user_id, "5")
      Metadata.increment("password_reset_count", "user", user_id)
  """

  alias OGrupoDeEstudos.Metadata.EntityMetadata
  alias OGrupoDeEstudos.Repo

  import Ecto.Query

  # ── Registered entity names ─────────────────────────────────────────

  @password_reset_count "password_reset_count"

  def password_reset_count_name, do: @password_reset_count

  # ── Public API ──────────────────────────────────────────────────────

  @doc "Returns the value for the given key, or nil if not found."
  def get(entity_name, entity_key_type, entity_key) do
    case Repo.get_by(EntityMetadata,
           entity_name: entity_name,
           entity_key_type: entity_key_type,
           entity_key: to_string(entity_key)
         ) do
      nil -> nil
      record -> record.entity_value
    end
  end

  @doc "Returns the value as integer, defaulting to 0 if not found."
  def get_integer(entity_name, entity_key_type, entity_key) do
    case get(entity_name, entity_key_type, entity_key) do
      nil -> 0
      value -> String.to_integer(value)
    end
  end

  @doc "Sets the value, creating or updating the record."
  def set(entity_name, entity_key_type, entity_key, value) do
    attrs = %{
      entity_name: entity_name,
      entity_key_type: entity_key_type,
      entity_key: to_string(entity_key),
      entity_value: to_string(value)
    }

    %EntityMetadata{}
    |> EntityMetadata.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [entity_value: to_string(value), updated_at: DateTime.utc_now()]],
      conflict_target: [:entity_name, :entity_key_type, :entity_key]
    )
  end

  @doc """
  Atomically increments the integer value by 1, creating with value "1"
  if it doesn't exist. Returns `{:ok, new_value}`.
  """
  def increment(entity_name, entity_key_type, entity_key) do
    key = to_string(entity_key)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all(
      EntityMetadata,
      [
        %{
          id: Ecto.UUID.generate(),
          entity_name: entity_name,
          entity_key_type: entity_key_type,
          entity_key: key,
          entity_value: "1",
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict:
        from(e in EntityMetadata,
          update: [
            set: [
              entity_value: fragment("(CAST(? AS integer) + 1)::text", e.entity_value),
              updated_at: ^now
            ]
          ]
        ),
      conflict_target: [:entity_name, :entity_key_type, :entity_key],
      returning: [:entity_value]
    )
    |> case do
      {1, [%{entity_value: val}]} -> {:ok, String.to_integer(val)}
      _ -> {:error, :increment_failed}
    end
  end
end

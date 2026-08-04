defmodule OGrupoDeEstudosWeb.InlineEditParams do
  @moduledoc """
  Which fields the pencil may write, and how a typed value becomes an attribute.

  A whitelist, and never the name that arrived in the event: the event comes from
  the browser, so trusting it would let anyone name a column and have it cast.
  """

  alias OGrupoDeEstudos.Brazil

  @workshop ~w(title description location price capacity payment_info starts_at address)a
  @program ~w(title description location price payment_info)a

  @address ~w(street street_number complement neighborhood city state postal_code)a

  @doc "The field as an atom, or nil when the page does not offer it."
  @spec workshop_field(String.t()) :: atom() | nil
  def workshop_field(name), do: offered(@workshop, name)

  @spec program_field(String.t()) :: atom() | nil
  def program_field(name), do: offered(@program, name)

  # Comparing strings against a fixed list, instead of to_existing_atom: an atom
  # that happens to exist elsewhere in the app is not the same as a field this page
  # meant to open.
  defp offered(fields, name) when is_binary(name),
    do: Enum.find(fields, &(to_string(&1) == name))

  defp offered(_fields, _name), do: nil

  @doc """
  The attributes a save should write, from what was typed.

  Takes the record because a field can depend on it: moving the start keeps the
  length of the class, which only the record knows.
  """
  @spec attrs(struct(), atom(), map()) :: map()
  def attrs(_record, :address, params) do
    Map.new(@address, fn field -> {field, blank_to_nil(params[to_string(field)])} end)
  end

  def attrs(_record, :price, %{"value" => value}), do: %{price_cents: parse_price(value)}
  def attrs(_record, :capacity, %{"value" => value}), do: %{capacity: parse_int(value)}

  # The end follows the start so the class keeps its length: whoever fixes a wrong
  # hour is not saying the workshop got longer.
  def attrs(record, :starts_at, %{"value" => value}) do
    %{starts_at: parse_datetime(value), duration_minutes: current_duration(record)}
  end

  def attrs(_record, field, %{"value" => value}), do: %{field => blank_to_nil(value)}
  def attrs(_record, _field, _params), do: %{}

  @doc "How the field reads inside the open input."
  @spec form_value(struct(), atom()) :: String.t()
  def form_value(record, :price), do: price_input(record.price_cents)
  def form_value(record, :capacity), do: to_string(record.capacity || "")
  def form_value(record, :starts_at), do: datetime_input(record.starts_at)
  def form_value(record, field), do: Map.get(record, field) || ""

  defp current_duration(%{starts_at: %DateTime{}, ends_at: %DateTime{}} = record),
    do: DateTime.diff(record.ends_at, record.starts_at, :minute)

  defp current_duration(_no_end), do: nil

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp parse_price(value) do
    case value |> to_string() |> String.replace(",", ".") |> Float.parse() do
      {reais, _rest} -> round(reais * 100)
      :error -> nil
    end
  end

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp parse_datetime(value) do
    case NaiveDateTime.from_iso8601(to_string(value) <> ":00") do
      {:ok, naive} ->
        naive
        |> DateTime.from_naive!("Etc/UTC")
        |> Brazil.to_utc()
        |> DateTime.truncate(:second)

      {:error, _reason} ->
        nil
    end
  end

  defp price_input(nil), do: ""
  defp price_input(cents), do: :erlang.float_to_binary(cents / 100, decimals: 2)

  defp datetime_input(nil), do: ""

  defp datetime_input(datetime),
    do: datetime |> Brazil.to_local() |> Calendar.strftime("%Y-%m-%dT%H:%M")
end

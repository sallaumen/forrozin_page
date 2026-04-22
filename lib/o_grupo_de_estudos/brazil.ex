defmodule OGrupoDeEstudos.Brazil do
  @moduledoc """
  Brazilian timezone and locale helpers. Curitiba is always UTC-3
  (Brazil stopped observing DST in 2019).

  Use `Brazil.today/0` instead of `Date.utc_today/0` to get the
  correct date for Brazilian users. Use `Brazil.to_local/1` to
  convert UTC timestamps before displaying.
  """

  @offset_seconds -3 * 3600

  @doc "Returns today's date in Brazilian time (UTC-3)."
  @spec today() :: Date.t()
  def today do
    DateTime.utc_now()
    |> DateTime.add(@offset_seconds)
    |> DateTime.to_date()
  end

  @doc "Converts a UTC datetime to Brazilian time (UTC-3)."
  def to_local(nil), do: nil
  def to_local(%DateTime{} = dt), do: DateTime.add(dt, @offset_seconds)
  def to_local(%NaiveDateTime{} = ndt), do: NaiveDateTime.add(ndt, @offset_seconds)

  @doc "Formats a date or UTC datetime as dd/mm/yyyy."
  def format_date(nil), do: ""
  def format_date(%Date{} = d), do: Calendar.strftime(d, "%d/%m/%Y")
  def format_date(dt), do: dt |> to_local() |> Calendar.strftime("%d/%m/%Y")

  @doc "Formats a UTC datetime as dd/mm/yyyy HH:MM in Brazilian time."
  def format_datetime(nil), do: ""
  def format_datetime(dt), do: dt |> to_local() |> Calendar.strftime("%d/%m/%Y %H:%M")

  @doc "Formats a UTC datetime as dd/mm/yyyy HH:MM:SS in Brazilian time."
  def format_datetime_full(nil), do: ""
  def format_datetime_full(dt), do: dt |> to_local() |> Calendar.strftime("%d/%m/%Y %H:%M:%S")

  @doc "Formats today's date in Portuguese (e.g., 'quarta-feira, 22 de abril')."
  def format_today do
    today() |> Calendar.strftime("%A, %d de %B", pt_br_opts())
  end

  @doc "Formats a date with month name in Portuguese (e.g., 'abril 2026')."
  def format_month_year(nil), do: ""
  def format_month_year(%Date{} = d), do: Calendar.strftime(d, "%B %Y", pt_br_opts())
  def format_month_year(dt), do: dt |> to_local() |> Calendar.strftime("%B %Y", pt_br_opts())

  @doc "Strftime with Portuguese locale. Use for custom formats with %A, %B, etc."
  def strftime(date_or_dt, format) do
    Calendar.strftime(date_or_dt, format, pt_br_opts())
  end

  # ── Portuguese locale ────────────────────────────────────────────────

  defp pt_br_opts do
    [
      day_of_week_names: &day_name/1,
      abbreviated_day_of_week_names: &day_abbr/1,
      month_names: &month_name/1,
      abbreviated_month_names: &month_abbr/1
    ]
  end

  defp day_name(1), do: "segunda-feira"
  defp day_name(2), do: "terça-feira"
  defp day_name(3), do: "quarta-feira"
  defp day_name(4), do: "quinta-feira"
  defp day_name(5), do: "sexta-feira"
  defp day_name(6), do: "sábado"
  defp day_name(7), do: "domingo"

  defp day_abbr(1), do: "seg"
  defp day_abbr(2), do: "ter"
  defp day_abbr(3), do: "qua"
  defp day_abbr(4), do: "qui"
  defp day_abbr(5), do: "sex"
  defp day_abbr(6), do: "sáb"
  defp day_abbr(7), do: "dom"

  defp month_name(1), do: "janeiro"
  defp month_name(2), do: "fevereiro"
  defp month_name(3), do: "março"
  defp month_name(4), do: "abril"
  defp month_name(5), do: "maio"
  defp month_name(6), do: "junho"
  defp month_name(7), do: "julho"
  defp month_name(8), do: "agosto"
  defp month_name(9), do: "setembro"
  defp month_name(10), do: "outubro"
  defp month_name(11), do: "novembro"
  defp month_name(12), do: "dezembro"

  defp month_abbr(1), do: "jan"
  defp month_abbr(2), do: "fev"
  defp month_abbr(3), do: "mar"
  defp month_abbr(4), do: "abr"
  defp month_abbr(5), do: "mai"
  defp month_abbr(6), do: "jun"
  defp month_abbr(7), do: "jul"
  defp month_abbr(8), do: "ago"
  defp month_abbr(9), do: "set"
  defp month_abbr(10), do: "out"
  defp month_abbr(11), do: "nov"
  defp month_abbr(12), do: "dez"
end

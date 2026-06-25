defmodule OGrupoDeEstudosWeb.WcagContrast do
  @moduledoc "WCAG 2.1 relative luminance contrast ratio. Pure helpers for tests."

  def ratio(fg_hex, bg_hex), do: contrast_ratio(luminance(fg_hex), luminance(bg_hex))

  defp contrast_ratio(l1, l2) when l1 >= l2, do: (l1 + 0.05) / (l2 + 0.05)
  defp contrast_ratio(l1, l2), do: (l2 + 0.05) / (l1 + 0.05)

  defp luminance(hex) do
    {r, g, b} = parse(hex)
    0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
  end

  defp parse("#" <> rest), do: parse(rest)

  defp parse(<<r::binary-2, g::binary-2, b::binary-2>>),
    do: {hex_to_int(r) / 255, hex_to_int(g) / 255, hex_to_int(b) / 255}

  defp hex_to_int(s), do: String.to_integer(s, 16)

  defp linearize(c) when c <= 0.03928, do: c / 12.92
  defp linearize(c), do: :math.pow((c + 0.055) / 1.055, 2.4)
end

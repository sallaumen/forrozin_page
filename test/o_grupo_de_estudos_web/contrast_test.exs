defmodule OGrupoDeEstudosWeb.ContrastTest do
  @moduledoc """
  Contrast rules that a template must not break, checked against the source.

  These are not style opinions: white on the orange scores 2.85:1 in the light
  theme and 2.19:1 in the dark one, where WCAG AA asks for 4.5:1 on text this
  size. It was the most important button in the product, on the platform where
  almost everyone is.

  The fix is a token that does *not* invert: the orange, the green and the gold
  stay light in both themes, so the text on them has to stay dark in both. The
  red and the purple are the other way round and keep white, which is why the
  rule below names the accents instead of banning `text-white` outright.
  """

  use ExUnit.Case, async: true

  @web_root "lib/o_grupo_de_estudos_web"
  @light_accents ~w(accent-orange accent-green gold-500 gold-600)

  defp templates do
    @web_root
    |> Path.join("**/*.{ex,heex}")
    |> Path.wildcard()
  end

  defp offending_lines(matcher) do
    for path <- templates(),
        {line, number} <- Enum.with_index(File.read!(path) |> String.split("\n"), 1),
        matcher.(line) do
      "#{Path.relative_to(path, @web_root)}:#{number}"
    end
  end

  describe "text on a filled accent" do
    test "the light accents never carry white text" do
      offenders =
        offending_lines(fn line ->
          String.contains?(line, "text-white") and
            Enum.any?(@light_accents, &String.contains?(line, "bg-#{&1}"))
        end)

      assert offenders == [],
             """
             Texto branco sobre acento claro dá 2,2 a 2,9:1. Use `text-on-accent`,
             que não inverte no tema escuro. Linhas: #{Enum.join(offenders, ", ")}
             """
    end

    test "on-accent is only for the accents it was measured against" do
      offenders =
        offending_lines(fn line ->
          String.contains?(line, "text-on-accent") and
            (String.contains?(line, "bg-accent-red") or
               String.contains?(line, "bg-accent-purple"))
        end)

      assert offenders == [],
             """
             No vermelho e no roxo o texto escuro é pior que o branco (3,2 contra
             5,4). Linhas: #{Enum.join(offenders, ", ")}
             """
    end
  end

  describe "the token values themselves" do
    test "the secondary grey clears 4.5:1 on the paper it is read on" do
      css = File.read!("assets/css/app.css")

      assert css =~ "--color-ink-500: #7f6247",
             "ink-500 é o cinza de 360 usos de texto; abaixo deste tom ele volta a falhar"
    end

    test "on-accent stays dark in the dark theme, which is the whole point" do
      css = File.read!("assets/css/app.css")
      [_, dark] = String.split(css, ".dark {", parts: 2)

      refute dark =~ "--color-on-accent",
             "se on-accent inverter, o texto vira claro sobre um laranja claro (1,89:1)"
    end
  end
end

defmodule OGrupoDeEstudosWeb.GraphDarkModeTest do
  use ExUnit.Case, async: true

  test "tokens dark sepia quente presentes em app.css" do
    css = File.read!("assets/css/app.css")
    assert css =~ ~r/--color-ink-50:\s*#1a120d/
    assert css =~ ~r/--color-ink-100:\s*#221511/
    assert css =~ ~r/--color-ink-900:\s*#f5ede4/
  end
end

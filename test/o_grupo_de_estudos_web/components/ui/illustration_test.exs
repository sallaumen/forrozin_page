defmodule OGrupoDeEstudosWeb.UI.IllustrationTest do
  @moduledoc """
  The slot that has to draw eleven drawings of eleven different sizes.

  Two rules, and every test here is one of them. Nothing is cropped, because the
  figure is a whole body and which part carries the step changes from step to
  step. Nothing is enlarged past what it can carry, because a drawing stretched
  past its own resolution looks broken in a way a smaller one never does.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias OGrupoDeEstudosWeb.UI.Illustration

  describe "what the library knows about each file" do
    test "what it measures is the file that actually gets served" do
      assert %{width: 640, height: 640, srcset: srcset} =
               Illustration.source("/images/collection/trava-frontal.png")

      assert srcset =~ "/images/collection/thumb/trava-frontal.webp 320w"
      assert srcset =~ "/images/collection/thumb/trava-frontal@640.webp 640w"
    end

    test "a drawing already smaller than the thumbnail was converted, never enlarged" do
      assert %{width: 310, height: 315} =
               Illustration.source("/images/collection/sacada-esquerda.png")
    end

    test "each file carries the green it was drawn on" do
      %{background: trava} = Illustration.source("/images/collection/trava-frontal.png")
      %{background: piao} = Illustration.source("/images/collection/piao.png")

      assert trava =~ ~r/^#[0-9a-f]{6}$/
      refute trava == piao, "os verdes diferem entre as ilustrações; casar um só deixa emenda"
    end

    test "a file nobody sampled is not invented" do
      refute Illustration.source("/uploads/whatever.png")
    end
  end

  describe "the ceiling, derived from the file's real size" do
    test "a 310 by 315 drawing stops well before it would blur" do
      assert {194, 197} = Illustration.crisp_ceiling("/images/collection/sacada-esquerda.png")
    end

    test "the mosaic tile of 271px fits inside every family drawing's ceiling" do
      familias =
        ~w(base inversao gp piao scsp caminhada pescada trava-frontal sacada-simples giro-simples)

      for nome <- familias do
        {largura, altura} = Illustration.crisp_ceiling("/images/collection/#{nome}.png")

        assert min(largura, altura) >= 271,
               "#{nome} pararia antes de preencher o mosaico e ficaria encolhida entre as vizinhas"
      end
    end

    test "a drawing nobody measured has no ceiling to enforce" do
      refute Illustration.crisp_ceiling("/uploads/whatever.png")
    end
  end

  describe "what the slot renders" do
    defp slot(path, opts \\ []) do
      render_component(
        &Illustration.illustration/1,
        Keyword.merge([src: path, alt: "Sacada", class: "aspect-[3/4]"], opts)
      )
    end

    test "it contains the drawing instead of cropping it" do
      html = slot("/images/collection/piao.png")

      assert html =~ "object-contain"
      refute html =~ "object-cover"
    end

    test "it paints the frame with the drawing's own green" do
      %{background: green} = Illustration.source("/images/collection/piao.png")

      assert slot("/images/collection/piao.png") =~ green
    end

    test "it caps a small drawing at the size it can carry" do
      html = slot("/images/collection/sacada-esquerda.png")

      assert html =~ "max-width:min(100%,194px)"
      assert html =~ "max-height:min(100%,197px)"
    end

    test "the frame is always a ceiling too, so nothing overflows and gets clipped" do
      for path <- ["/images/collection/piao.png", "/uploads/whatever.png"] do
        assert slot(path) =~ "max-width:min(100%," or slot(path) =~ "max-width:100%"
      end
    end

    test "it reserves the space before the file arrives" do
      html = slot("/images/collection/piao.png")

      assert html =~ ~s(width="640")
      assert html =~ ~s(height="640")
      assert html =~ ~s(loading="lazy")
    end

    test "it serves a hundred kilobytes instead of eleven megabytes" do
      html = slot("/images/collection/piao.png")

      assert html =~ "/images/collection/thumb/piao.webp 320w"
      assert html =~ "/images/collection/thumb/piao@640.webp 640w"
      assert html =~ ~s(type="image/webp")

      assert html =~ "/images/collection/piao.png",
             "o PNG original continua como alternativa de quem não lê webp"
    end

    test "an unmeasured file still renders, held to the frame and nothing more" do
      html = slot("/uploads/whatever.png")

      assert html =~ "/uploads/whatever.png"
      assert html =~ "max-width:100%"
      refute html =~ "px)", "sem medida do arquivo não há teto de resolução a aplicar"
    end

    test "the drawing is described for whoever cannot see it" do
      assert slot("/images/collection/piao.png") =~ ~s(alt="Sacada")
    end
  end
end

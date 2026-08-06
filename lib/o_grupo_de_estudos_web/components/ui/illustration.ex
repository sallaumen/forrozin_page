defmodule OGrupoDeEstudosWeb.UI.Illustration do
  @moduledoc """
  The frame that draws a step illustration, whatever size it was drawn at.

  The eleven drawings came in at eleven different sizes, from 1774x1774 down to
  310x315, and each sits on a flat green that is nearly, but not exactly, the
  same green as the others. Three rules follow, and the whole module is those
  three rules.

  **Nothing is cropped.** The figure is a whole body and which part carries the
  step changes with the step: the foot in a trava, the hand above the head in a
  giro. So the fit is `contain`, never `cover`, and the frame is painted with
  the drawing's own corner colour. The padding then reads as more drawing rather
  than as letterboxing, and the frame is free to be any shape.

  **Nothing is enlarged past what it can carry.** Each drawing carries its own
  ceiling, derived from its real size; above it the drawing sits smaller inside
  the green, which looks deliberate, where a blurred enlargement looks broken.
  The ceiling is where the drawing still holds up, not where it is
  pixel-perfect: see `@density`.

  **Nothing arrives heavier than the frame needs.** The originals total eleven
  megabytes, which is an absurd price for a row of 54 pixel marks. Two WebP
  derivatives are served instead — 320px for the marks, 640px for the acervo
  mosaic — and the browser picks by `sizes`. The original PNG stays as the
  fallback of the `<picture>`, for whoever cannot read WebP. The two drawings
  that were already smaller were converted, never enlarged.

  A file nobody measured (a future upload) renders straight from its own path.
  Refusing to draw it would be worse than drawing it unmeasured.
  """

  use OGrupoDeEstudosWeb, :html

  # Cada desenho tem duas versões: a pequena para a marca de 54px das listas, a
  # grande para o mosaico do acervo. As medidas são as da VERSÃO GRANDE, que é o
  # teto de nitidez real, e a cor vem dos quatro cantos do arquivo — a borda
  # inteira não serve, porque em sacada-esquerda os pés dos gatos encostam
  # embaixo e puxam a média para o pelo.
  #
  # Nenhuma foi ampliada: as duas que já nasceram menores que 640 aparecem aqui
  # no próprio tamanho.
  @library %{
    "/images/collection/base.png" => {"base", 470, 640, "#4c5841"},
    "/images/collection/inversao.png" => {"inversao", 640, 640, "#4b5140"},
    "/images/collection/gp.png" => {"gp", 640, 640, "#515b44"},
    "/images/collection/piao.png" => {"piao", 640, 640, "#4b513f"},
    "/images/collection/scsp.png" => {"scsp", 640, 640, "#4c543d"},
    "/images/collection/caminhada.png" => {"caminhada", 640, 640, "#535c45"},
    "/images/collection/pescada.png" => {"pescada", 640, 640, "#505744"},
    "/images/collection/trava-frontal.png" => {"trava-frontal", 640, 640, "#4f5845"},
    "/images/collection/sacada-simples.png" => {"sacada-simples", 481, 481, "#4d5b4a"},
    "/images/collection/sacada-esquerda.png" => {"sacada-esquerda", 310, 315, "#4c5848"},
    "/images/collection/giro-simples.png" => {"giro-simples", 568, 640, "#535c41"}
  }

  # Dois pixels de tela por pixel de CSS é o ideal num celular. Mas o teto é o
  # ponto onde o desenho AINDA se segura, não o ponto onde ele fica perfeito:
  # abaixo de 1,6 a suavização começa a aparecer, e acima disso não. Com 2
  # cravado, a `sacada-simples` (481px nativos) parava em 240 dentro de um
  # mosaico de 271 e ficava visivelmente encolhida no meio das vizinhas — uma
  # emenda pior do que os 10% de nitidez que ela economizava.
  @density 1.6

  @doc """
  What is known about a drawing: the file that gets served, its size and its green.
  """
  def source(path), do: build_source(Map.get(@library, path))

  defp build_source(nil), do: nil

  defp build_source({name, width, height, background}) do
    %{
      srcset:
        "/images/collection/thumb/#{name}.webp 320w, /images/collection/thumb/#{name}@640.webp #{width}w",
      width: width,
      height: height,
      background: background
    }
  end

  @doc """
  The largest size a drawing can be shown at before it goes soft.
  """
  def crisp_ceiling(path), do: ceiling_of(Map.get(@library, path))

  defp ceiling_of(nil), do: nil

  defp ceiling_of({_name, width, height, _background}),
    do: {ceiling_px(width), ceiling_px(height)}

  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :class, :string, default: ""

  attr :sizes, :string,
    default: "54px",
    doc: "largura em CSS que a moldura terá, para o navegador escolher a versão certa"

  attr :rest, :global

  def illustration(assigns) do
    assigns = assign(assigns, :source, source(assigns.src))

    ~H"""
    <%!-- flex, não grid: numa grade de um item só a linha é dimensionada pelo
         conteúdo e o conteúdo pela linha, então `max-height: 100%` vira `none` e
         a ilustração estoura a moldura. Num flex de altura fixa a porcentagem
         tem contra o que resolver. --%>
    <div
      class={["flex items-center justify-center overflow-hidden", @class]}
      style={@source && "background-color: #{@source.background}"}
      {@rest}
    >
      <picture class="contents">
        <source :if={@source} srcset={@source.srcset} sizes={@sizes} type="image/webp" />
        <img
          src={@src}
          alt={@alt}
          width={@source && @source.width}
          height={@source && @source.height}
          loading="lazy"
          decoding="async"
          class="object-contain"
          style={cap(@source)}
        />
      </picture>
    </div>
    """
  end

  # Two ceilings at once, and the smaller one wins: the frame, so the drawing is
  # never clipped, and the file's own resolution, so it is never enlarged into
  # mush. `h-full` cannot do the first job here, because a centred grid item
  # sizes the row and the row sizes the item, and the percentage resolves to
  # auto: the drawing then overflows the frame and gets cropped by it.
  defp cap(nil), do: "max-width:100%;max-height:100%"

  defp cap(%{width: width, height: height}) do
    "max-width:min(100%,#{ceiling_px(width)}px);max-height:min(100%,#{ceiling_px(height)}px)"
  end

  defp ceiling_px(pixels), do: round(pixels / @density)
end

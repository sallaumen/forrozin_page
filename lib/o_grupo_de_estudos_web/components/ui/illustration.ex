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

  **Nothing is enlarged past what it can carry.** A phone draws two device
  pixels per CSS pixel, so a 310px drawing is sharp up to 155 CSS pixels and
  soft after that. Each drawing carries its own ceiling; above it the drawing
  sits smaller inside the green, which looks deliberate, where a blurred
  enlargement looks broken.

  **Nothing arrives heavier than the frame needs.** The originals total eleven
  megabytes, which is an absurd price for a row of 54 pixel marks, so what gets
  served is a 320px WebP: a hundred kilobytes for all eleven. The original PNG
  stays as the fallback of the `<picture>`, for whoever cannot read WebP. The
  two drawings that were already smaller than 320 were converted, never
  enlarged.

  A file nobody measured (a future upload) renders straight from its own path.
  Refusing to draw it would be worse than drawing it unmeasured.
  """

  use OGrupoDeEstudosWeb, :html

  # Sizes and colours are of the *thumbnail*, because the thumbnail is what
  # browsers actually receive. The colour is sampled from the four corners,
  # which are background on all eleven; whole edges are not safe, since in
  # sacada-esquerda the cats' feet reach the bottom and drag the average
  # towards the fur.
  @library %{
    "/images/collection/base.png" => {"base", 235, 320, "#4c5841"},
    "/images/collection/inversao.png" => {"inversao", 320, 320, "#4b5140"},
    "/images/collection/gp.png" => {"gp", 320, 320, "#515b44"},
    "/images/collection/piao.png" => {"piao", 320, 320, "#4b513f"},
    "/images/collection/scsp.png" => {"scsp", 320, 320, "#4c543d"},
    "/images/collection/caminhada.png" => {"caminhada", 320, 320, "#535c45"},
    "/images/collection/pescada.png" => {"pescada", 320, 320, "#505744"},
    "/images/collection/trava-frontal.png" => {"trava-frontal", 320, 320, "#4f5845"},
    "/images/collection/sacada-simples.png" => {"sacada-simples", 320, 320, "#4d5b4a"},
    "/images/collection/sacada-esquerda.png" => {"sacada-esquerda", 310, 315, "#4c5848"},
    "/images/collection/giro-simples.png" => {"giro-simples", 284, 320, "#535c41"}
  }

  # Every phone this app runs on draws two device pixels per CSS pixel.
  @device_pixel_ratio 2

  @doc """
  What is known about a drawing: the file that gets served, its size and its green.
  """
  def source(path), do: build_source(Map.get(@library, path))

  defp build_source(nil), do: nil

  defp build_source({name, width, height, background}) do
    %{
      thumb: "/images/collection/thumb/#{name}.webp",
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
    do: {div(width, @device_pixel_ratio), div(height, @device_pixel_ratio)}

  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :class, :string, default: ""
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
        <source :if={@source} srcset={@source.thumb} type="image/webp" />
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
    "max-width:min(100%,#{div(width, @device_pixel_ratio)}px);" <>
      "max-height:min(100%,#{div(height, @device_pixel_ratio)}px)"
  end
end

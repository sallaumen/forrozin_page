defmodule OGrupoDeEstudosWeb.UI.InlineEdit do
  @moduledoc """
  A pencil beside a field, for whoever may change it.

  Whoever organizes reads the published page far more often than the form, and most
  corrections are one field: a wrong hour, a missing number on the street. Opening
  the form, finding that field among twenty and coming back is the long way around
  for a two-second fix.

  The page owns the events (`edit_field`, `save_field`, `cancel_edit`) because what
  a save means differs per page; this module owns only how it looks and behaves.
  """

  use OGrupoDeEstudosWeb, :html

  alias OGrupoDeEstudos.Brazil

  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :editing, :atom, default: nil
  attr :can_edit, :boolean, default: false
  attr :type, :atom, values: [:text, :long_text, :number, :money, :datetime], default: :text
  attr :value, :any, default: nil
  attr :hint, :string, default: nil
  attr :error, :string, default: nil
  attr :layout, :atom, values: [:inline, :block], default: :inline
  slot :inner_block, required: true

  @doc """
  The value as it reads, with a pencil; or the field open for typing.

  The wrapper is a `div` and the caller passes its own `h1`, `p` or `span` inside
  the slot. A `form` may not live inside a heading or a paragraph: the browser
  closes the element early and the layout falls apart around it.
  """
  def editable(assigns) do
    ~H"""
    <div>
      <.read_view
        :if={@editing != @field}
        field={@field}
        label={@label}
        can_edit={@can_edit}
        layout={@layout}
      >
        {render_slot(@inner_block)}
      </.read_view>

      <form
        :if={@editing == @field}
        phx-submit="save_field"
        phx-window-keydown="cancel_edit"
        phx-key="escape"
        class="my-1 block w-full max-w-[32rem]"
      >
        <label
          for={"inline-#{@field}"}
          class="mb-1 block text-[10px] font-bold uppercase tracking-[1.3px] text-ink-500"
        >
          {@label}
        </label>

        <textarea
          :if={@type == :long_text}
          id={"inline-#{@field}"}
          name="value"
          rows="6"
          phx-mounted={JS.focus()}
          class={field_class()}
        >{@value}</textarea>

        <input
          :if={@type != :long_text}
          id={"inline-#{@field}"}
          type={input_type(@type)}
          inputmode={inputmode(@type)}
          name="value"
          value={@value}
          phx-mounted={JS.focus()}
          class={field_class()}
        />

        <p :if={@hint} class="m-0 mt-1 text-[11.5px] leading-snug text-ink-500">{@hint}</p>
        <p :if={@error} class="m-0 mt-1 text-[11.5px] font-semibold text-accent-red">{@error}</p>

        <.buttons />
      </form>
    </div>
    """
  end

  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :editing, :atom, default: nil
  attr :can_edit, :boolean, default: false
  attr :workshop, :map, required: true
  attr :states, :list, required: true
  attr :error, :string, default: nil
  slot :inner_block, required: true

  @doc """
  The address, which is one question made of several fields.

  Opening them one pencil at a time would mean six rounds to fix one address, so
  the whole block opens together.
  """
  def editable_address(assigns) do
    ~H"""
    <div>
      <.read_view
        :if={@editing != @field}
        field={@field}
        label={@label}
        can_edit={@can_edit}
        layout={:block}
      >
        {render_slot(@inner_block)}
      </.read_view>

      <form
        :if={@editing == @field}
        phx-submit="save_field"
        phx-window-keydown="cancel_edit"
        phx-key="escape"
        class="my-2 block w-full max-w-[32rem] rounded-xl border border-ink-200 bg-ink-100/40 p-3"
      >
        <p class="m-0 mb-2 text-[10px] font-bold uppercase tracking-[1.3px] text-ink-500">
          {@label}
        </p>

        <div class="grid grid-cols-[1fr_5rem] gap-2">
          <input
            type="text"
            name="street"
            value={@workshop.street}
            placeholder="Rua"
            aria-label="Rua"
            phx-mounted={JS.focus()}
            class={field_class()}
          />
          <input
            type="text"
            inputmode="numeric"
            name="street_number"
            value={@workshop.street_number}
            placeholder="Nº"
            aria-label="Número"
            class={field_class()}
          />
        </div>

        <input
          type="text"
          name="complement"
          value={@workshop.complement}
          placeholder="Complemento (opcional)"
          aria-label="Complemento"
          class={[field_class(), "mt-2"]}
        />
        <input
          type="text"
          name="neighborhood"
          value={@workshop.neighborhood}
          placeholder="Bairro"
          aria-label="Bairro"
          class={[field_class(), "mt-2"]}
        />

        <div class="mt-2 grid grid-cols-[1fr_5rem] gap-2">
          <input
            type="text"
            name="city"
            value={@workshop.city}
            placeholder="Cidade"
            aria-label="Cidade"
            class={field_class()}
          />
          <select name="state" aria-label="Estado" class={field_class()}>
            <option value="" selected={@workshop.state in [nil, ""]}>UF</option>
            <option :for={uf <- @states} value={uf} selected={@workshop.state == uf}>{uf}</option>
          </select>
        </div>

        <input
          type="text"
          inputmode="numeric"
          name="postal_code"
          value={@workshop.postal_code}
          placeholder="CEP (opcional)"
          aria-label="CEP"
          class={[field_class(), "mt-2"]}
        />

        <p :if={@error} class="m-0 mt-1 text-[11.5px] font-semibold text-accent-red">{@error}</p>

        <.buttons />
      </form>
    </div>
    """
  end

  attr :at, :any, default: nil

  @doc "When the record was last touched. Quiet on purpose: it is a footnote, not news."
  def last_updated(assigns) do
    ~H"""
    <p :if={@at} class="m-0 mt-8 border-t border-ink-200 pt-3 text-[11px] text-ink-500">
      Última atualização em {Brazil.format_datetime_full(@at)}
    </p>
    """
  end

  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :can_edit, :boolean, required: true
  attr :layout, :atom, required: true
  slot :inner_block, required: true

  # Inline for a short value, where the pencil sits right after the words. Block for
  # anything that wraps: sharing the row there costs the text 36px of width and
  # forces a line break that would not exist otherwise, so the pencil floats at the
  # top corner instead and the text keeps the whole column.
  defp read_view(%{layout: :block} = assigns) do
    ~H"""
    <div class="relative">
      <div class={@can_edit && "pr-9"}>{render_slot(@inner_block)}</div>
      <%!-- The corner is on a wrapper and not on the button: the button needs its own
      `relative` for the invisible hit area, and Tailwind orders `relative` after
      `absolute`, so positioning it directly would be quietly cancelled. --%>
      <span :if={@can_edit} class="absolute right-0 top-0">
        <.pencil field={@field} label={@label} />
      </span>
    </div>
    """
  end

  defp read_view(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-1">
      {render_slot(@inner_block)}
      <.pencil :if={@can_edit} field={@field} label={@label} />
    </div>
    """
  end

  attr :field, :atom, required: true
  attr :label, :string, required: true

  # Always visible, never hover-only: on a phone there is no hover, and a control
  # nobody can discover is a control nobody has. The glyph stays small so it does
  # not shout next to the title; the invisible box around it is the 44px a finger
  # needs.
  defp pencil(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="edit_field"
      phx-value-field={@field}
      aria-label={"Editar #{@label}"}
      title={"Editar #{@label}"}
      class="relative inline-grid size-8 shrink-0 cursor-pointer place-items-center rounded-full text-ink-300 transition-colors after:absolute after:left-1/2 after:top-1/2 after:size-11 after:-translate-x-1/2 after:-translate-y-1/2 after:content-[''] hover:bg-ink-200 hover:text-ink-700"
    >
      <.icon name="hero-pencil-square" class="size-3.5" />
    </button>
    """
  end

  defp buttons(assigns) do
    ~H"""
    <div class="mt-2 flex items-center gap-2">
      <button
        type="submit"
        phx-disable-with="Salvando..."
        class="min-h-11 cursor-pointer rounded-full border-0 bg-ink-900 px-5 text-[13px] font-semibold text-ink-50 sm:min-h-9"
      >
        Salvar
      </button>
      <button
        type="button"
        phx-click="cancel_edit"
        class="min-h-11 cursor-pointer rounded-full border border-ink-300 bg-ink-50 px-5 text-[13px] font-semibold text-ink-600 sm:min-h-9"
      >
        Cancelar
      </button>
    </div>
    """
  end

  # 16px on the phone and not 13.5px: below 16, iOS zooms the page in the moment the
  # field takes focus, and the person has to pinch back out to keep typing. The
  # smaller size returns from `sm` up, where no browser does that.
  defp field_class,
    do:
      "min-h-11 w-full rounded-lg border border-ink-300 bg-ink-50 px-3 py-2 font-serif text-[16px] text-ink-900 placeholder:text-ink-400 sm:min-h-0 sm:text-[13.5px]"

  defp input_type(:datetime), do: "datetime-local"
  defp input_type(:number), do: "number"
  defp input_type(_text), do: "text"

  defp inputmode(:money), do: "decimal"
  defp inputmode(:number), do: "numeric"
  defp inputmode(_other), do: nil
end

defmodule OGrupoDeEstudosWeb.UI.Select do
  @moduledoc """
  Dropdown nativo com label, prompt opcional, options, hint, error.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true

  attr :options, :list, required: true,
    doc: "list of {label, value} tuples"

  attr :value, :string, default: nil
  attr :prompt, :string, default: nil, doc: "placeholder option shown first"

  attr :hint, :string, default: nil
  attr :errors, :list, default: []
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(required disabled)

  def select(assigns) do
    assigns =
      assigns
      |> assign(:has_error?, assigns.errors != [])
      |> assign(:describedby, describedby(assigns.id, assigns.hint, assigns.errors))

    ~H"""
    <div data-ui="select">
      <label for={@id} class="block text-xs font-sans font-semibold text-ink-700 mb-1 tracking-wider uppercase">
        {@label}
      </label>
      <select
        id={@id}
        name={@name}
        aria-invalid={if @has_error?, do: "true"}
        aria-describedby={@describedby}
        class={[
          "w-full px-3 py-2 text-base font-sans text-ink-900",
          "bg-ink-50 border rounded-md",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ink-900",
          "disabled:opacity-60 disabled:cursor-not-allowed",
          if(@has_error?, do: "border-accent-red", else: "border-ink-300"),
          @class
        ]}
        {@rest}
      >
        <option :if={@prompt} value="" disabled selected={is_nil(@value)}>{@prompt}</option>
        <option
          :for={{label, val} <- @options}
          value={val}
          selected={to_string(val) == to_string(@value)}
        >
          {label}
        </option>
      </select>
      <p :if={@hint && !@has_error?} id={"#{@id}-hint"} class="text-xs text-ink-500 mt-1">
        {@hint}
      </p>
      <p :for={err <- @errors} id={"#{@id}-error"} class="text-xs text-accent-red mt-1">
        {err}
      </p>
    </div>
    """
  end

  defp describedby(_id, nil, []), do: nil
  defp describedby(id, _hint, errors) when errors != [], do: "#{id}-error"
  defp describedby(id, _hint, _errors), do: "#{id}-hint"
end

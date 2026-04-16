defmodule OGrupoDeEstudosWeb.UI.BackButton do
  @moduledoc """
  Botão voltar para contexto de navegação detalhe no mobile.

  Comportamento via JS hook `BackButton`:
  - Se `window.history.length > 1`, chama `history.back()` (volta pra
    página de onde veio)
  - Senão, navega para `:fallback` (default `/collection`)

  Aceita múltiplas instâncias na mesma página via `:id`.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, default: "back-button"
  attr :label, :string, default: "Voltar"
  attr :fallback, :string, default: "/collection"
  attr :class, :any, default: nil

  def back_button(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      data-ui="back-button"
      data-fallback={@fallback}
      aria-label={@label}
      phx-hook="BackButton"
      class={[
        "inline-flex items-center justify-center w-11 h-11 rounded-md",
        "text-ink-100 hover:bg-ink-700 active:scale-95 transition-colors",
        "cursor-pointer",
        @class
      ]}
    >
      <.icon name="hero-chevron-left" class="size-5" />
    </button>
    """
  end
end

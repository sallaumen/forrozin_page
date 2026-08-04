defmodule OGrupoDeEstudosWeb.UI.GoogleSignIn do
  @moduledoc """
  Google sign-in button and logo.

  The button renders only when Google OAuth credentials are configured
  (`Accounts.GoogleAuth.configured?/0`), so environments without
  credentials simply hide it.
  """

  use OGrupoDeEstudosWeb, :html

  alias OGrupoDeEstudos.Accounts.GoogleAuth

  @doc "Whether the sign-in button (and any wrapper around it) should render."
  defdelegate google_auth_configured?, to: GoogleAuth, as: :configured?

  attr :label, :string, required: true
  attr :teacher_invite, :string, default: nil

  def google_sign_in_button(assigns) do
    ~H"""
    <a
      href={google_auth_path(@teacher_invite)}
      class="w-full py-[13px] bg-ink-50 border border-[rgba(60,40,20,0.25)] rounded font-serif text-base text-ink-800 flex items-center justify-center gap-3 no-underline hover:bg-ink-100"
    >
      <.google_logo size={18} />
      {@label}
    </a>
    """
  end

  attr :size, :integer, default: 18
  attr :class, :string, default: nil

  def google_logo(assigns) do
    ~H"""
    <svg
      width={@size}
      height={@size}
      viewBox="0 0 48 48"
      aria-hidden="true"
      class={@class}
    >
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
    """
  end

  defp google_auth_path(teacher_invite) when teacher_invite in [nil, ""], do: ~p"/auth/google"

  defp google_auth_path(teacher_invite),
    do: ~p"/auth/google?teacher_invite=#{teacher_invite}"
end

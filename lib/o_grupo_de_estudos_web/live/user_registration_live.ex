defmodule OGrupoDeEstudosWeb.UserRegistrationLive do
  @moduledoc false

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Study

  on_mount {OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated}

  @impl true
  def mount(params, _session, socket) do
    teacher_invite_slug = params["teacher_invite"]

    {:ok,
     assign(socket,
       page_title: "Cadastro",
       teacher_invite_slug: teacher_invite_slug,
       form: to_form(%{}, as: :user)
     )}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %Accounts.User{}
      |> Accounts.User.registration_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("register", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        maybe_accept_teacher_invite(user, socket.assigns.teacher_invite_slug)
        token = Phoenix.Token.sign(OGrupoDeEstudosWeb.Endpoint, "auto_login", user.id)

        {:noreply,
         socket
         |> push_event("form_persisted_clear", %{id: "registration-form"})
         |> put_flash(:info, "Conta criada! Verifique seu email para confirmar.")
         |> redirect(to: ~p"/auto-login/#{token}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Corrija os erros abaixo para criar sua conta.")
         |> assign(form: to_form(Map.put(changeset, :action, :validate), as: :user))}
    end
  end

  defp maybe_accept_teacher_invite(_user, nil), do: :ok
  defp maybe_accept_teacher_invite(_user, ""), do: :ok

  defp maybe_accept_teacher_invite(user, teacher_invite_slug) do
    case Study.accept_invite(user, teacher_invite_slug) do
      {:ok, _link} -> :ok
      _ -> :ok
    end
  end
end

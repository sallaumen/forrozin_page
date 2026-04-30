defmodule OGrupoDeEstudosWeb.SettingsLive do
  @moduledoc """
  User settings page.

  Allows an authenticated user to edit their profile (bio, Instagram handle)
  and upload an avatar image.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Media.Storage

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(
        page_title: "Configurações",
        is_admin: Accounts.admin?(user),
        avatar_path: user.avatar_path,
        country: user.country || "BR",
        bio_length: String.length(user.bio || ""),
        invite_url: invite_url(user.invite_slug),
        invite_message: invite_message(user),
        error: nil,
        saved: false,
        form: build_form(user)
      )
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 2_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_profile(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:country, params["country"] || socket.assigns.country)
     |> assign(:bio_length, String.length(params["bio"] || ""))
     |> assign(:saved, false)
     |> assign(:error, nil)
     |> assign(:form, to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    user = socket.assigns.current_user

    {avatar_path, socket} = consume_avatar_upload(socket, user)

    attrs =
      %{
        "name" => params["name"],
        "username" => params["username"],
        "country" => params["country"],
        "state" => params["state"],
        "city" => params["city"],
        "bio" => params["bio"],
        "instagram" => params["instagram"],
        "is_teacher" => params["is_teacher"]
      }
      |> maybe_put_avatar(avatar_path)

    case Accounts.update_profile(user, attrs) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> push_event("form_persisted_clear", %{id: "settings-form"})
         |> put_flash(:info, "Perfil salvo!")
         |> assign(
           current_user: updated_user,
           country: updated_user.country || "BR",
           bio_length: String.length(updated_user.bio || ""),
           avatar_path: updated_user.avatar_path,
           invite_url: invite_url(updated_user.invite_slug),
           invite_message: invite_message(updated_user),
           form: build_form(updated_user),
           saved: true,
           error: nil
         )}

      {:error, changeset} ->
        errors =
          Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} ->
            "#{field}: #{msg}"
          end)

        {:noreply,
         socket
         |> assign(:error, errors)
         |> assign(:saved, false)
         |> assign(:country, params["country"] || socket.assigns.country)
         |> assign(:bio_length, String.length(params["bio"] || ""))
         |> assign(:form, to_form(Map.put(changeset, :action, :validate), as: :user))}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  # --- helpers ---

  defp consume_avatar_upload(socket, user) do
    uploaded =
      consume_uploaded_entries(socket, :avatar, fn %{path: tmp_path}, entry ->
        ext = ext_from_entry(entry)
        Storage.save_avatar(user.id, tmp_path, ext)
      end)

    case uploaded do
      [{:ok, path}] -> {path, socket}
      [{:error, reason}] -> {nil, put_flash(socket, :error, "Erro ao salvar foto: #{reason}")}
      [] -> {nil, socket}
    end
  end

  defp ext_from_entry(%Phoenix.LiveView.UploadEntry{client_name: name}) do
    name |> Path.extname() |> String.downcase()
  end

  defp build_form(user, attrs \\ %{}) do
    user
    |> Accounts.change_profile(attrs)
    |> to_form(as: :user)
  end

  defp maybe_put_avatar(attrs, nil), do: attrs
  defp maybe_put_avatar(attrs, path), do: Map.put(attrs, "avatar_path", path)

  defp invite_url(invite_slug) do
    OGrupoDeEstudosWeb.Endpoint.url() <> "/study/invite/" <> invite_slug
  end

  defp invite_message(user) do
    "Oi! Vamos estudar forró juntos no O Grupo de Estudos? Entra por aqui: #{invite_url(user.invite_slug)}"
  end

  def upload_error_to_string(:too_large), do: "Arquivo muito grande (máx. 2 MB)."
  def upload_error_to_string(:not_accepted), do: "Formato não aceito. Use JPG, PNG ou WebP."
  def upload_error_to_string(:too_many_files), do: "Apenas um arquivo por vez."
  def upload_error_to_string(_), do: "Erro no upload."
end

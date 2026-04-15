defmodule ForrozinWeb.SettingsLive do
  @moduledoc """
  User settings page.

  Allows an authenticated user to edit their profile (bio, Instagram handle)
  and upload an avatar image.
  """

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(
        page_title: "Configurações",
        is_admin: Accounts.admin?(user),
        bio: user.bio || "",
        instagram: user.instagram || "",
        avatar_path: user.avatar_path,
        error: nil,
        saved: false
      )
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 2_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"bio" => bio, "instagram" => instagram}, socket) do
    {:noreply, assign(socket, bio: bio, instagram: instagram, saved: false, error: nil)}
  end

  @impl true
  def handle_event("save", %{"bio" => bio, "instagram" => instagram}, socket) do
    user = socket.assigns.current_user

    {avatar_path, socket} = consume_avatar_upload(socket, user)

    attrs =
      %{bio: bio, instagram: instagram}
      |> maybe_put_avatar(avatar_path)

    case Accounts.update_profile(user, attrs) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(
           bio: updated_user.bio || "",
           instagram: updated_user.instagram || "",
           avatar_path: updated_user.avatar_path,
           saved: true,
           error: nil
         )}

      {:error, changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, assign(socket, error: errors, saved: false)}
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
        dest_dir = Application.app_dir(:forrozin, "priv/static/uploads/avatars")
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, "#{user.id}#{ext}")
        File.cp!(tmp_path, dest)
        {:ok, "/uploads/avatars/#{user.id}#{ext}"}
      end)

    case uploaded do
      [path] -> {path, socket}
      [] -> {nil, socket}
    end
  end

  defp ext_from_entry(%Phoenix.LiveView.UploadEntry{client_name: name}) do
    name |> Path.extname() |> String.downcase()
  end

  defp maybe_put_avatar(attrs, nil), do: attrs
  defp maybe_put_avatar(attrs, path), do: Map.put(attrs, :avatar_path, path)

  def upload_error_to_string(:too_large), do: "Arquivo muito grande (máx. 2 MB)."
  def upload_error_to_string(:not_accepted), do: "Formato não aceito. Use JPG, PNG ou WebP."
  def upload_error_to_string(:too_many_files), do: "Apenas um arquivo por vez."
  def upload_error_to_string(_), do: "Erro no upload."
end

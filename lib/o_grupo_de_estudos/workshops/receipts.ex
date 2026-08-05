defmodule OGrupoDeEstudos.Workshops.Receipts do
  @moduledoc """
  Payment receipt attached to an enrollment.

  It exists so sending the receipt does not have to leave the app: the file goes
  up on the same page where the person enrolled and lands next to the button
  that confirms the payment.

  A receipt carries bank data, so it never reaches the gallery and never goes
  through `Plug.Static`: it is stored private and served by a controller that
  asks who is calling.

  The functions here take any enrollment that carries the `receipt_*` fields, so
  the workshop and the package share one rule instead of two copies of it.
  """

  alias Ecto.Changeset
  alias OGrupoDeEstudos.Media.Storage
  alias OGrupoDeEstudos.Repo

  # What a bank app actually hands over: a screenshot or a PDF.
  @accepted ~w(image/jpeg image/png image/webp application/pdf)
  @max_bytes 10_485_760

  @type upload :: %{tmp_path: String.t(), content_type: String.t(), byte_size: pos_integer()}
  @type reason :: :unsupported_type | :too_large | term()

  @doc "Content types the upload accepts."
  @spec accepted_types() :: [String.t()]
  def accepted_types, do: @accepted

  @doc "Size ceiling of a receipt, in bytes."
  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_bytes

  @doc """
  Stores the file and points the enrollment at it, replacing whatever was there.
  """
  @spec attach(struct(), String.t(), upload()) :: {:ok, struct()} | {:error, reason()}
  def attach(enrollment, folder, %{
        tmp_path: tmp_path,
        content_type: content_type,
        byte_size: byte_size
      }) do
    with :ok <- ensure_type(content_type),
         :ok <- ensure_size(byte_size),
         {:ok, key} <- Storage.put_private(folder, tmp_path, extension(content_type)) do
      enrollment
      |> point_at(key, content_type, byte_size)
      |> discard_previous(enrollment.receipt_key)
    end
  end

  @doc "Clears the receipt from the enrollment and deletes the file."
  @spec detach(struct()) :: {:ok, struct()} | {:error, term()}
  def detach(%{receipt_key: nil} = enrollment), do: {:ok, enrollment}

  def detach(%{receipt_key: key} = enrollment) do
    enrollment
    |> Changeset.change(
      receipt_key: nil,
      receipt_content_type: nil,
      receipt_byte_size: nil,
      receipt_sent_at: nil
    )
    |> Repo.update()
    |> discard_previous(key)
  end

  @doc "How to serve the file: `{:file, path}` or `{:redirect, url}`."
  @spec serve(struct()) :: {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}
  def serve(%{receipt_key: nil}), do: {:error, :not_found}
  def serve(%{receipt_key: key}), do: Storage.serve_private(key)

  defp point_at(enrollment, key, content_type, byte_size) do
    enrollment
    |> Changeset.change(
      receipt_key: key,
      receipt_content_type: content_type,
      receipt_byte_size: byte_size,
      receipt_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update()
  end

  # The old file only goes after the row already points somewhere else: an orphan
  # file is cheaper than a row pointing at a file that no longer exists.
  defp discard_previous({:ok, updated}, nil), do: {:ok, updated}

  defp discard_previous({:ok, updated}, key) do
    Storage.delete_private(key)
    {:ok, updated}
  end

  defp discard_previous(error, _key), do: error

  defp ensure_type(content_type) when content_type in @accepted, do: :ok
  defp ensure_type(_other), do: {:error, :unsupported_type}

  defp ensure_size(byte_size) when byte_size <= @max_bytes, do: :ok
  defp ensure_size(_too_big), do: {:error, :too_large}

  defp extension(content_type) do
    case MIME.extensions(content_type) do
      [ext | _] -> "." <> ext
      [] -> ".bin"
    end
  end
end

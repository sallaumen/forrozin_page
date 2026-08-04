defmodule OGrupoDeEstudos.Media.ObjectStorage.Behaviour do
  @moduledoc """
  Object storage port: bytes go in and out by opaque key.

  It is the ONLY contract an external provider (S3, Tigris, R2) has to implement
  for the storage to leave the local disk. On purpose it knows nothing about
  avatars, flyers or galleries: file naming, resizing and permission are policy
  of `Media.Storage` and of the domain, and do not change when the provider does.

  The key is an opaque relative path ("avatars/u1_99.jpg"). The caller decides the
  key; the adapter decides where the bytes live.
  """

  @doc "Writes the source file at the key. Overwrites when it already exists."
  @callback put(key :: String.t(), source_path :: String.t()) :: :ok | {:error, term()}

  @doc "Deletes the object. Silent when it is already gone."
  @callback delete(key :: String.t()) :: :ok | {:error, term()}

  @callback exists?(key :: String.t()) :: boolean()

  @doc "Keys starting with the prefix. For cleanup (old avatars)."
  @callback list(prefix :: String.t()) :: [String.t()]

  @doc "Public URL of an object served without authorization (avatar, flyer)."
  @callback public_url(key :: String.t()) :: String.t()

  @doc """
  How to serve a restricted object: `{:file, path}` for `send_file`, or
  `{:redirect, url}` when the provider generates a signed URL.

  The media controller handles both; the adapter picks what it has.
  """
  @callback serve(key :: String.t()) ::
              {:file, String.t()} | {:redirect, String.t()} | {:error, :not_found}

  @doc """
  Runs `fun` with a readable local path of the object (input for ffmpeg or
  Mogrify). On disk it is the file itself; on an external provider the adapter
  downloads to a temporary one and cleans up afterwards.
  """
  @callback with_local_file(key :: String.t(), fun :: (String.t() -> result)) ::
              {:ok, result} | {:error, term()}
            when result: term()

  @doc "Free bytes, or `:unknown` when the provider does not expose it (or does not limit)."
  @callback free_bytes() :: non_neg_integer() | :unknown
end

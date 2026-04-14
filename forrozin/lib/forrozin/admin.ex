defmodule Forrozin.Admin do
  @moduledoc """
  Administrative action context.

  Responsible for operations that modify the encyclopedia state.
  Authorization is the responsibility of the Web layer (LiveViews/Plugs).
  """

  alias Forrozin.Encyclopedia.Connection
  alias Forrozin.Repo

  @doc """
  Creates a directional connection between two steps.

  Returns `{:ok, connection}` or `{:error, changeset}`.
  """
  def create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the label or description of an existing connection.

  Returns `{:ok, connection}` or `{:error, :not_found}`.
  """
  def update_connection(id, attrs) do
    case Repo.get(Connection, id) do
      nil -> {:error, :not_found}
      connection -> connection |> Connection.changeset(attrs) |> Repo.update()
    end
  end

  @doc """
  Removes a connection by ID.

  Returns `{:ok, connection}` or `{:error, :not_found}`.
  """
  def delete_connection(id) do
    case Repo.get(Connection, id) do
      nil -> {:error, :not_found}
      connection -> Repo.delete(connection)
    end
  end
end

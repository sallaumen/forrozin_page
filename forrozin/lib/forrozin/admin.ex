defmodule Forrozin.Admin do
  @moduledoc """
  Administrative action context.

  Responsible for operations that modify the encyclopedia state.
  Authorization is the responsibility of the Web layer (LiveViews/Plugs).
  """

  alias Forrozin.Encyclopedia.{Category, Connection, Section, Step, Subsection}
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
  Soft-deletes a connection by ID (sets deleted_at).

  Returns `{:ok, connection}` or `{:error, :not_found}`.
  """
  def delete_connection(id) do
    case Repo.get(Connection, id) do
      nil ->
        {:error, :not_found}

      connection ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        connection |> Ecto.Changeset.change(deleted_at: now) |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Steps
  # ---------------------------------------------------------------------------

  def create_step(attrs) do
    %Step{} |> Step.changeset(attrs) |> Repo.insert()
  end

  def update_step(%Step{} = step, attrs) do
    step |> Step.changeset(attrs) |> Repo.update()
  end

  def delete_step(%Step{} = step) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    step |> Ecto.Changeset.change(deleted_at: now) |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  def create_section(attrs) do
    %Section{} |> Section.changeset(attrs) |> Repo.insert()
  end

  def update_section(%Section{} = section, attrs) do
    section |> Section.changeset(attrs) |> Repo.update()
  end

  def delete_section(%Section{} = section), do: Repo.delete(section)

  # ---------------------------------------------------------------------------
  # Subsections
  # ---------------------------------------------------------------------------

  def create_subsection(attrs) do
    %Subsection{} |> Subsection.changeset(attrs) |> Repo.insert()
  end

  def update_subsection(%Subsection{} = sub, attrs) do
    sub |> Subsection.changeset(attrs) |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  def create_category(attrs) do
    %Category{} |> Category.changeset(attrs) |> Repo.insert()
  end

  def update_category(%Category{} = cat, attrs) do
    cat |> Category.changeset(attrs) |> Repo.update()
  end
end

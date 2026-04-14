defmodule Forrozin.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Forrozin.Repo

  alias Forrozin.Accounts.User
  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Connection, Step, Section, Subsection}

  def user_factory do
    %User{
      username: sequence(:username, &"usuario#{&1}"),
      email: sequence(:email, &"usuario#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "user",
      state: "PR",
      city: "Curitiba",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def admin_factory do
    %User{
      username: sequence(:username, &"admin#{&1}"),
      email: sequence(:email, &"admin#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "admin",
      state: "PR",
      city: "Curitiba",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def category_factory do
    %Category{
      name: sequence(:category_name, &"category_#{&1}"),
      label: sequence(:category_label, &"Category #{&1}"),
      color: "#c0392b"
    }
  end

  def section_factory do
    %Section{
      title: sequence(:section_title, &"Section #{&1}"),
      position: sequence(:section_position, & &1),
      category: build(:category)
    }
  end

  def subsection_factory do
    %Subsection{
      title: sequence(:subsection_title, &"Subsection #{&1}"),
      position: sequence(:subsection_position, & &1),
      section: build(:section)
    }
  end

  def step_factory do
    %Step{
      code: sequence(:step_code, &"P#{&1}"),
      name: sequence(:step_name, &"Step #{&1}"),
      position: sequence(:step_position, & &1),
      section: build(:section),
      category: build(:category)
    }
  end

  def connection_factory do
    %Connection{
      source_step: build(:step),
      target_step: build(:step)
    }
  end

  def technical_concept_factory do
    %TechnicalConcept{
      title: sequence(:concept_title, &"Concept #{&1}"),
      description: "Technical description of the concept."
    }
  end
end

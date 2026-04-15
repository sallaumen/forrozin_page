defmodule Forrozin.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Forrozin.Repo

  alias Forrozin.Accounts.User

  alias Forrozin.Encyclopedia.{
    Category,
    TechnicalConcept,
    Connection,
    Step,
    Section,
    StepLink,
    Subsection
  }

  alias Forrozin.Engagement.Like
  alias Forrozin.Sequences.{Sequence, SequenceStep}

  def user_factory do
    %User{
      username: sequence(:username, &"usuario#{&1}"),
      name: sequence(:name, &"Usuário Teste #{&1}"),
      email: sequence(:email, &"usuario#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "user",
      country: "BR",
      state: "PR",
      city: "Curitiba",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def admin_factory do
    %User{
      username: sequence(:username, &"admin#{&1}"),
      name: sequence(:name, &"Admin Teste #{&1}"),
      email: sequence(:email, &"admin#{&1}@example.com"),
      password_hash: Argon2.hash_pwd_salt("senhateste123"),
      role: "admin",
      country: "BR",
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

  def sequence_factory do
    %Sequence{
      name: sequence(:sequence_name, &"Sequência #{&1}"),
      allow_repeats: false,
      user: build(:user)
    }
  end

  def sequence_step_factory do
    %SequenceStep{
      position: sequence(:sequence_step_position, & &1),
      sequence: build(:sequence),
      step: build(:step)
    }
  end

  def step_link_factory do
    %StepLink{
      url: sequence(:step_link_url, &"https://example.com/link#{&1}"),
      title: sequence(:step_link_title, &"Link #{&1}"),
      approved: false,
      step: build(:step),
      submitted_by: build(:user)
    }
  end

  def like_factory do
    %Like{
      likeable_type: "step",
      likeable_id: Ecto.UUID.generate(),
      user: build(:user)
    }
  end
end

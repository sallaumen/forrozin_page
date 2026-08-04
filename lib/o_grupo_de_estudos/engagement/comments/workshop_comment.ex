defmodule OGrupoDeEstudos.Engagement.Comments.WorkshopComment do
  @moduledoc """
  Conversa na página de um workshop.

  Tabela própria, como as demais: o projeto generaliza comentário pelo
  behaviour `Commentable`, não por parent polimórfico.

  De propósito fora de `Engagement.Metrics`: badge e estatística de perfil
  medem contribuição ao acervo, e workshop é evento, não acervo.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_comments" do
    field :body, :string
    field :deleted_at, :utc_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :workshop, OGrupoDeEstudos.Workshops.Workshop
    belongs_to :parent_comment, __MODULE__, foreign_key: :parent_workshop_comment_id

    has_many :replies, __MODULE__,
      foreign_key: :parent_workshop_comment_id,
      where: [deleted_at: nil]

    # Naive on purpose: comment_thread measures "5 min ago" with NaiveDateTime.
    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :workshop_id, :parent_workshop_comment_id])
    |> validate_required([:body, :user_id, :workshop_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:parent_workshop_comment_id)
  end
end

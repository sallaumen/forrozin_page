defmodule OGrupoDeEstudos.Engagement.Comments.Commentable do
  @moduledoc "Behaviour defining shared query contract for all comment types."

  @callback base_query() :: Ecto.Query.t()
  @callback for_parent(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  @callback roots_only(Ecto.Query.t()) :: Ecto.Query.t()
  @callback replies_for(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  @callback ordered_by_engagement(Ecto.Query.t()) :: Ecto.Query.t()
  @callback schema() :: module()
  @callback parent_field() :: atom()
  @callback parent_comment_field() :: atom()
  @callback likeable_type() :: String.t()
end

defmodule OGrupoDeEstudos.Repo do
  use Ecto.Repo,
    otp_app: :o_grupo_de_estudos,
    adapter: Ecto.Adapters.Postgres
end

defmodule Forrozin.Repo do
  use Ecto.Repo,
    otp_app: :forrozin,
    adapter: Ecto.Adapters.Postgres
end

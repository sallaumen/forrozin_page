# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Forrozin.Repo.insert!(%Forrozin.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

result = Forrozin.Encyclopedia.Seeder.seed!()
IO.puts("Seed: #{result}")

# Admin padrão — pré-confirmado, sem email de verificação
import Ecto.Query, only: [where: 2]

unless Forrozin.Repo.exists?(where(Forrozin.Accounts.User, nome_usuario: "tata")) do
  Forrozin.Repo.insert!(%Forrozin.Accounts.User{
    nome_usuario: "tata",
    email: "tata@forrozin.com.br",
    senha_hash: Argon2.hash_pwd_salt("forroisloveforroislife"),
    papel: "admin",
    confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  })

  IO.puts("Seed: admin tata criado")
end

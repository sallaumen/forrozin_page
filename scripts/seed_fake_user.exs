# scripts/seed_fake_user.exs
#
# Creates a user account stuffed with fake data across all tables.
# Purpose: stress-test UI with lots of data (scroll, pagination, performance).
#
# Usage:
#   mix run scripts/seed_fake_user.exs
#   mix run scripts/seed_fake_user.exs --dry-run
#
# NEVER run in production — guard enforced.

Code.require_file("scripts/script_helper.exs")

alias OGrupoDeEstudos.{Accounts, Admin, Engagement, Sequences, Repo}
alias OGrupoDeEstudos.Encyclopedia.{Step, StepQuery, Section}
alias OGrupoDeEstudos.Engagement.{Like, Favorite, Follow}
alias OGrupoDeEstudos.Engagement.Comments.StepComment
alias OGrupoDeEstudos.Sequences.{Sequence, SequenceStep}

import Ecto.Query

ScriptHelper.guard_not_production!()

dry_run = ScriptHelper.dry_run?()

if dry_run do
  ScriptHelper.log(:warn, "DRY RUN MODE: no data will be written")
end

IO.puts("""

\e[1m=== SEED FAKE USER ===\e[0m
Creates a user with lots of fake engagement data.
""")

# ── 1. Create fake user ──────────────────────────────────────────────

ScriptHelper.log(:step, "Creating fake user")

username = "fake_user_#{:rand.uniform(9999)}"

user_attrs = %{
  username: username,
  name: "Usuario Fake #{:rand.uniform(100)}",
  email: "#{username}@fake.local",
  password: "fakefake123",
  country: "BR",
  state: "PR",
  city: Enum.random(["Curitiba", "Sao Paulo", "Rio de Janeiro", "Belo Horizonte", "Salvador"]),
  bio: "Conta de teste gerada automaticamente para validar interfaces com muito dado."
}

user =
  if dry_run do
    ScriptHelper.log(:info, "Would create user @#{username}")
    %{id: "dry-run", username: username}
  else
    {:ok, u} = Accounts.register_user(user_attrs)
    # Confirm immediately
    Repo.update!(Ecto.Changeset.change(u, confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)))
    ScriptHelper.log(:ok, "User @#{u.username} created (#{u.id})")
    u
  end

# ── 2. Get existing steps ────────────────────────────────────────────

ScriptHelper.log(:step, "Loading existing steps")

steps = Repo.all(from s in Step, where: is_nil(s.deleted_at) and s.status == "published", limit: 50)
ScriptHelper.log(:info, "Found #{length(steps)} published steps")

if steps == [] do
  ScriptHelper.log(:error, "No steps found. Run seeds first.")
  System.halt(1)
end

# ── 3. Like random steps ─────────────────────────────────────────────

ScriptHelper.log(:step, "Liking random steps")

liked_steps = Enum.take_random(steps, min(20, length(steps)))

unless dry_run do
  Enum.each(liked_steps, fn step ->
    Engagement.toggle_like(user.id, "step", step.id)
  end)
end

ScriptHelper.log(:ok, "Liked #{length(liked_steps)} steps")

# ── 4. Favorite some steps ───────────────────────────────────────────

ScriptHelper.log(:step, "Favoriting random steps")

fav_steps = Enum.take_random(liked_steps, min(8, length(liked_steps)))

unless dry_run do
  Enum.each(fav_steps, fn step ->
    Engagement.toggle_favorite(user.id, "step", step.id)
  end)
end

ScriptHelper.log(:ok, "Favorited #{length(fav_steps)} steps")

# ── 5. Comment on random steps ───────────────────────────────────────

ScriptHelper.log(:step, "Commenting on random steps")

comment_steps = Enum.take_random(steps, min(15, length(steps)))
comments_created = []

fake_comments = [
  "Esse passo é muito bom pra quem tá comecando!",
  "Acho que a nota podia ser mais detalhada.",
  "Funciona melhor com musica lenta.",
  "Meu preferido pra aula de sabado.",
  "Precisa de mais pratica, mas vale a pena.",
  "Combinacao top com sacada simples.",
  "Descobri esse ontem, muito legal!",
  "A conexao com o giro paulista faz sentido.",
  "Nao conhecia esse nome, sempre chamei diferente.",
  "Da pra variar bastante a partir daqui.",
  "Otimo passo pra conduzir iniciantes.",
  "Um pouco dificil no comeco, mas depois flui.",
  "A mecanica do centro de massa e chave aqui.",
  "Sempre uso esse na roda de forro.",
  "Base fundamental pra tudo."
]

unless dry_run do
  comments_created =
    Enum.map(comment_steps, fn step ->
      body = Enum.random(fake_comments)
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: body})
      comment
    end)
end

ScriptHelper.log(:ok, "Created #{length(comment_steps)} comments")

# ── 6. Reply to some comments ────────────────────────────────────────

ScriptHelper.log(:step, "Replying to own comments")

unless dry_run do
  reply_comments = Enum.take_random(comments_created, min(5, length(comments_created)))

  Enum.each(reply_comments, fn comment ->
    Engagement.create_step_comment(user, comment.step_id, %{
      body: "Pensando melhor, concordo com o que falei!",
      parent_step_comment_id: comment.id
    })
  end)

  ScriptHelper.log(:ok, "Created #{length(reply_comments)} replies")
end

# ── 7. Suggest some steps ────────────────────────────────────────────

ScriptHelper.log(:step, "Suggesting fake steps")

fake_steps = [
  %{"name" => "Fake Sacada Invertida", "code" => "FK-SI-#{:rand.uniform(999)}"},
  %{"name" => "Fake Giro Maluco", "code" => "FK-GM-#{:rand.uniform(999)}"},
  %{"name" => "Fake Base Lateral Roots", "code" => "FK-BLR-#{:rand.uniform(999)}"},
  %{"name" => "Fake Trava Dupla", "code" => "FK-TD-#{:rand.uniform(999)}"},
  %{"name" => "Fake Caminhada Reversa", "code" => "FK-CR-#{:rand.uniform(999)}"}
]

sections = Repo.all(from s in Section, limit: 3)
section_id = if sections != [], do: hd(sections).id, else: nil

unless dry_run do
  Enum.each(fake_steps, fn step_attrs ->
    attrs = Map.merge(step_attrs, %{
      "suggested_by_id" => user.id,
      "section_id" => section_id || "",
      "note" => "Passo fake gerado por script de teste."
    })
    Admin.create_step(attrs)
  end)
end

ScriptHelper.log(:ok, "Suggested #{length(fake_steps)} fake steps")

# ── 8. Create sequences ─────────────────────────────────────────────

ScriptHelper.log(:step, "Creating fake sequences")

unless dry_run do
  for i <- 1..3 do
    seq_steps = Enum.take_random(steps, Enum.random(4..8))

    {:ok, seq} = Repo.insert(%Sequence{
      name: "Sequencia Fake #{i}",
      user_id: user.id,
      public: true,
      description: "Sequencia gerada automaticamente para testes."
    })

    seq_steps
    |> Enum.with_index()
    |> Enum.each(fn {step, pos} ->
      Repo.insert!(%SequenceStep{
        sequence_id: seq.id,
        step_id: step.id,
        position: pos
      })
    end)
  end
end

ScriptHelper.log(:ok, "Created 3 fake sequences")

# ── 9. Follow some users ─────────────────────────────────────────────

ScriptHelper.log(:step, "Following random users")

other_users = Repo.all(from u in OGrupoDeEstudos.Accounts.User,
  where: u.id != ^user.id,
  limit: 10
)

unless dry_run do
  Enum.each(Enum.take_random(other_users, min(5, length(other_users))), fn other ->
    Engagement.toggle_follow(user.id, other.id)
  end)
end

ScriptHelper.log(:ok, "Followed #{min(5, length(other_users))} users")

# ── Summary ──────────────────────────────────────────────────────────

IO.puts("""

\e[1m=== DONE ===\e[0m
  User: @#{user.username}
  #{if dry_run, do: "(DRY RUN: nothing was written)", else: "Login: #{user_attrs.email} / #{user_attrs.password}"}

  Data created:
    #{length(liked_steps)} likes
    #{length(fav_steps)} favorites
    #{length(comment_steps)} comments + replies
    #{length(fake_steps)} suggested steps
    3 sequences
    #{min(5, length(other_users))} follows
""")

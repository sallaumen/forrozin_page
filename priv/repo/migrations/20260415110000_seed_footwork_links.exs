defmodule Forrozin.Repo.Migrations.SeedFootworkLinks do
  use Ecto.Migration

  def up do
    # Seed Instagram links from @forro_footwork channel
    # submitted_by_id is NULL — these are system-provided links, not community submissions
    # All links are pre-approved (approved: true)

    links = [
      {"HF-PT", "Push Turn", "https://www.instagram.com/p/DTGVKpAjfWr/"},
      {"HF-PT", "Push Turn (variação)", "https://www.instagram.com/p/DExAx7Wt32I/"},
      {"HF-STS", "Side to Slide", "https://www.instagram.com/p/DTBhbz5jSmJ/"},
      {"HF-CAB", "Caminhada Block", "https://www.instagram.com/p/C0o200AtOQ5/"},
      {"HF-CAB", "Opções ao final da caminhada", "https://www.instagram.com/p/DOO9okqDQlE/"},
      {"HF-IP1", "Interrupted Paulista", "https://www.instagram.com/p/DJjMq1GtS2o/"},
      {"HF-AWK", "Armwork Masterclass", "https://www.instagram.com/p/C1hfHpvNYs6/"},
      {"HF-AWK", "Wonderful Flourish", "https://www.instagram.com/p/DIZDH61NqLV/"},
      {"HF-SRS", "Suspended Rotating Sacada", "https://www.instagram.com/p/DCqdSjFOe4l/"},
      {"HF-TDC", "Trocadilho do Condutor", "https://www.instagram.com/p/C9aSJB4taOw/"},
      {"HF-EN", "Vem Neném", "https://www.instagram.com/p/C9Sbro4tQGg/"},
      {"HF-YNK", "Yoink", "https://www.instagram.com/p/C6pSovZhCLD/"},
      {"HF-DD", "Double Duckerfly", "https://www.instagram.com/p/C5d7ta7ibWX/"},
      {"HF-RS", "Reverse Sacada", "https://www.instagram.com/p/C5YYPmntukR/"},
      {"HF-CWB", "Cowboy Sequence", "https://www.instagram.com/p/C5LgHMPtO1h/"},
      {"HF-A5T", "Avião into 5 Step Turn", "https://www.instagram.com/p/C49CiYxt2el/"},
      {"HF-MV7", "7 Step Variation", "https://www.instagram.com/p/C1UZXg9tV-n/"},
      {"HF-WO5", "Mr. Miyagi (Wax On)", "https://www.instagram.com/p/C04Y5SfNN0t/"},
      {"HF-PRC", "Paulista Release Come Back Twist", "https://www.instagram.com/p/Cz6M2SWtmQM/"},
      {"HF-SLC", "Sacada Leg Catch", "https://www.instagram.com/p/C0l-zVdtKyY/"},
      {"HF-S3", "Side to Side to Side", "https://www.instagram.com/p/Cz8woOKNbdU/"},
      {"HF-HHS", "Hand to Hand Slide", "https://www.instagram.com/p/Cz081ajtn3b/"},
      {"HF-SCA", "Sacada com Arrastada", "https://www.instagram.com/p/Czyiav9twd5/"},
      {"HF-HRB", "High Right Block Spin", "https://www.instagram.com/p/Czj3UtXLDNl/"},
      {"HF-PLS", "Pêndulo Lateral + Sacada + Caminhada",
       "https://www.instagram.com/p/Czl6TBkNzll/"},
      {"HF-TAS", "Turn Away Spin Overhead", "https://www.instagram.com/p/CzbRMaht982/"},
      {"HF-R2R", "Right to Right Block Block Block", "https://www.instagram.com/p/C6KRzcNtUaL/"},
      {"HF-R2L", "Right to Left Spin Continuation", "https://www.instagram.com/p/C0EfDsmtXkk/"},
      {"HF-PBV", "The Paulista (variação)", "https://www.instagram.com/p/Czo9OocOcSk/"},
      {"SCxX", "Alternating Sacadas", "https://www.instagram.com/p/C6Zk0jNRZZJ/"},
      {"SCxX", "Sacada esquerda, sacada direita", "https://www.instagram.com/p/C4_dEkINIjg/"},
      {"PI", "O Pião (entrada pelo abraço lateral)", "https://www.instagram.com/p/C0uIxs4NSpi/"},
      {"HF-PS", "Pazazz", "https://www.instagram.com/p/C6hEm8uhYgu/"}
    ]

    for {code, title, url} <- links do
      execute """
      INSERT INTO step_links (id, url, title, approved, step_id, submitted_by_id, inserted_at, updated_at)
      SELECT
        gen_random_uuid(),
        '#{url}',
        '#{String.replace(title, "'", "''")}',
        true,
        s.id,
        (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
        NOW(),
        NOW()
      FROM steps s
      WHERE s.code = '#{code}'
        AND s.deleted_at IS NULL
      ON CONFLICT DO NOTHING
      """
    end
  end

  def down do
    execute "DELETE FROM step_links WHERE url LIKE '%instagram.com/p/%'"
  end
end

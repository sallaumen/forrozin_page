defmodule OGrupoDeEstudos.Repo.Migrations.CreateEngagementTriggers do
  use Ecto.Migration

  def up do
    # ── like_count trigger ──────────────────────────────────────────────────

    execute("""
    CREATE OR REPLACE FUNCTION update_like_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' THEN
        IF NEW.likeable_type = 'step_comment' THEN
          UPDATE step_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
        ELSIF NEW.likeable_type = 'sequence_comment' THEN
          UPDATE sequence_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
        ELSIF NEW.likeable_type = 'profile_comment' THEN
          UPDATE profile_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
        ELSIF NEW.likeable_type = 'step' THEN
          UPDATE steps SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
        ELSIF NEW.likeable_type = 'sequence' THEN
          UPDATE sequences SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
        END IF;
      ELSIF TG_OP = 'DELETE' THEN
        IF OLD.likeable_type = 'step_comment' THEN
          UPDATE step_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
        ELSIF OLD.likeable_type = 'sequence_comment' THEN
          UPDATE sequence_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
        ELSIF OLD.likeable_type = 'profile_comment' THEN
          UPDATE profile_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
        ELSIF OLD.likeable_type = 'step' THEN
          UPDATE steps SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
        ELSIF OLD.likeable_type = 'sequence' THEN
          UPDATE sequences SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
        END IF;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER likes_update_count
    AFTER INSERT OR DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION update_like_count();
    """)

    # ── reply_count trigger — step_comments ─────────────────────────────────

    execute("""
    CREATE OR REPLACE FUNCTION update_step_comments_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_step_comment_id IS NOT NULL THEN
        UPDATE step_comments SET reply_count = reply_count + 1 WHERE id = NEW.parent_step_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_step_comment_id IS NOT NULL THEN
        UPDATE step_comments SET reply_count = reply_count - 1 WHERE id = OLD.parent_step_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER step_comments_reply_count
    AFTER INSERT OR DELETE ON step_comments
    FOR EACH ROW EXECUTE FUNCTION update_step_comments_reply_count();
    """)

    # ── reply_count trigger — sequence_comments ──────────────────────────────

    execute("""
    CREATE OR REPLACE FUNCTION update_sequence_comments_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_sequence_comment_id IS NOT NULL THEN
        UPDATE sequence_comments SET reply_count = reply_count + 1 WHERE id = NEW.parent_sequence_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_sequence_comment_id IS NOT NULL THEN
        UPDATE sequence_comments SET reply_count = reply_count - 1 WHERE id = OLD.parent_sequence_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER sequence_comments_reply_count
    AFTER INSERT OR DELETE ON sequence_comments
    FOR EACH ROW EXECUTE FUNCTION update_sequence_comments_reply_count();
    """)

    # ── reply_count trigger — profile_comments ───────────────────────────────

    execute("""
    CREATE OR REPLACE FUNCTION update_profile_comments_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_profile_comment_id IS NOT NULL THEN
        UPDATE profile_comments SET reply_count = reply_count + 1 WHERE id = NEW.parent_profile_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_profile_comment_id IS NOT NULL THEN
        UPDATE profile_comments SET reply_count = reply_count - 1 WHERE id = OLD.parent_profile_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER profile_comments_reply_count
    AFTER INSERT OR DELETE ON profile_comments
    FOR EACH ROW EXECUTE FUNCTION update_profile_comments_reply_count();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS likes_update_count ON likes")
    execute("DROP FUNCTION IF EXISTS update_like_count()")

    execute("DROP TRIGGER IF EXISTS step_comments_reply_count ON step_comments")
    execute("DROP FUNCTION IF EXISTS update_step_comments_reply_count()")

    execute("DROP TRIGGER IF EXISTS sequence_comments_reply_count ON sequence_comments")
    execute("DROP FUNCTION IF EXISTS update_sequence_comments_reply_count()")

    execute("DROP TRIGGER IF EXISTS profile_comments_reply_count ON profile_comments")
    execute("DROP FUNCTION IF EXISTS update_profile_comments_reply_count()")
  end
end

defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopCommentTriggers do
  use Ecto.Migration

  # CREATE OR REPLACE swaps the ENTIRE function body, so the branches of
  # 20260417000403 are pasted here literally along with the new one. The
  # likes_update_count trigger already points at this function by name, which is
  # why it is not recreated.
  def up do
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
        ELSIF NEW.likeable_type = 'workshop_comment' THEN
          UPDATE workshop_comments SET like_count = like_count + 1 WHERE id = NEW.likeable_id;
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
        ELSIF OLD.likeable_type = 'workshop_comment' THEN
          UPDATE workshop_comments SET like_count = like_count - 1 WHERE id = OLD.likeable_id;
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
    CREATE OR REPLACE FUNCTION update_workshop_comments_reply_count() RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'INSERT' AND NEW.parent_workshop_comment_id IS NOT NULL THEN
        UPDATE workshop_comments SET reply_count = reply_count + 1
          WHERE id = NEW.parent_workshop_comment_id;
      ELSIF TG_OP = 'DELETE' AND OLD.parent_workshop_comment_id IS NOT NULL THEN
        UPDATE workshop_comments SET reply_count = reply_count - 1
          WHERE id = OLD.parent_workshop_comment_id;
      END IF;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER workshop_comments_reply_count
    AFTER INSERT OR DELETE ON workshop_comments
    FOR EACH ROW EXECUTE FUNCTION update_workshop_comments_reply_count();
    """)
  end

  # Restores the like function to the body of 20260417000403, without the workshop branch.
  def down do
    execute("DROP TRIGGER IF EXISTS workshop_comments_reply_count ON workshop_comments;")
    execute("DROP FUNCTION IF EXISTS update_workshop_comments_reply_count();")

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
  end
end

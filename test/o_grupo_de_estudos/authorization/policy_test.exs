defmodule OGrupoDeEstudos.Authorization.PolicyTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopComment
  alias OGrupoDeEstudos.Workshops.{Access, Workshop, WorkshopMedia}

  defp access(workshop, user, admin?) do
    %Access{
      workshop: workshop,
      user_id: user.id,
      owner?: admin?,
      admin?: admin?,
      enrolled?: true
    }
  end

  describe "authorize(:delete_comment, user, comment)" do
    test "admin can delete any comment" do
      admin = insert(:admin)
      comment = insert(:step_comment)
      assert :ok = Policy.authorize(:delete_comment, admin, comment)
    end

    test "author can delete own comment" do
      user = insert(:user)
      comment = insert(:step_comment, user: user)
      assert :ok = Policy.authorize(:delete_comment, user, comment)
    end

    test "other user cannot delete someone else's comment" do
      user = insert(:user)
      comment = insert(:step_comment)
      assert {:error, :unauthorized} = Policy.authorize(:delete_comment, user, comment)
    end
  end

  describe "authorize(:delete_comment, user, {comment, access})" do
    setup do
      organizer = insert(:user)
      author = insert(:user)
      workshop = insert(:workshop, organizer: organizer)

      %{
        organizer: organizer,
        author: author,
        workshop: workshop,
        comment: %WorkshopComment{user_id: author.id}
      }
    end

    test "whoever runs the workshop takes down a comment from anyone", ctx do
      subject = {ctx.comment, access(ctx.workshop, ctx.organizer, true)}

      assert :ok = Policy.authorize(:delete_comment, ctx.organizer, subject)
    end

    test "whoever wrote it still takes down their own", ctx do
      subject = {ctx.comment, access(ctx.workshop, ctx.author, false)}

      assert :ok = Policy.authorize(:delete_comment, ctx.author, subject)
    end

    test "anyone else takes down nothing", ctx do
      other = insert(:user)
      subject = {ctx.comment, access(ctx.workshop, other, false)}

      assert {:error, :unauthorized} = Policy.authorize(:delete_comment, other, subject)
    end
  end

  describe "authorize(:delete_media, user, {media, access})" do
    setup do
      organizer = insert(:user)
      author = insert(:user)
      workshop = insert(:workshop, organizer: organizer)

      %{
        organizer: organizer,
        author: author,
        workshop: workshop,
        media: %WorkshopMedia{uploaded_by_id: author.id}
      }
    end

    test "whoever uploaded takes their own out of the gallery", ctx do
      subject = {ctx.media, access(ctx.workshop, ctx.author, false)}

      assert :ok = Policy.authorize(:delete_media, ctx.author, subject)
    end

    test "whoever runs the workshop takes out media from anyone", ctx do
      subject = {ctx.media, access(ctx.workshop, ctx.organizer, true)}

      assert :ok = Policy.authorize(:delete_media, ctx.organizer, subject)
    end

    test "anyone else takes out nothing", ctx do
      other = insert(:user)
      subject = {ctx.media, access(ctx.workshop, other, false)}

      assert {:error, :unauthorized} = Policy.authorize(:delete_media, other, subject)
    end
  end

  describe "authorize(:create_comment, user, _)" do
    test "authenticated user can create comments" do
      user = insert(:user)
      assert :ok = Policy.authorize(:create_comment, user, nil)
    end

    test "nil user cannot create comments" do
      assert {:error, :unauthenticated} = Policy.authorize(:create_comment, nil, nil)
    end
  end

  describe "authorize(:edit_step, user, step)" do
    test "admin can edit any step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:edit_step, admin, step)
    end

    test "suggester can edit the step they suggested" do
      user = insert(:user)
      step = insert(:step, suggested_by: user)
      assert :ok = Policy.authorize(:edit_step, user, step)
    end

    test "other user cannot edit a step" do
      user = insert(:user)
      step = insert(:step)
      assert {:error, :unauthorized} = Policy.authorize(:edit_step, user, step)
    end
  end

  describe "authorize(:delete_step, user, step)" do
    test "admin can delete a step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:delete_step, admin, step)
    end

    test "suggester cannot delete the step they suggested" do
      user = insert(:user)
      step = insert(:step, suggested_by: user)
      assert {:error, :unauthorized} = Policy.authorize(:delete_step, user, step)
    end
  end

  describe "authorize(:approve_step, user, step)" do
    test "admin can approve a step" do
      admin = insert(:admin)
      step = insert(:step)
      assert :ok = Policy.authorize(:approve_step, admin, step)
    end

    test "regular user cannot approve a step" do
      user = insert(:user)
      step = insert(:step)
      assert {:error, :unauthorized} = Policy.authorize(:approve_step, user, step)
    end
  end

  describe "authorize(:manage_section, user, _)" do
    test "admin can manage sections and categories" do
      admin = insert(:admin)
      assert :ok = Policy.authorize(:manage_section, admin, nil)
    end

    test "regular user cannot manage sections" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_section, user, nil)
    end
  end

  describe "authorize(:manage_step_link, user, link)" do
    test "admin can manage any link" do
      admin = insert(:admin)
      link = insert(:step_link)
      assert :ok = Policy.authorize(:manage_step_link, admin, link)
    end

    test "submitter can manage the link they submitted" do
      user = insert(:user)
      link = insert(:step_link, submitted_by: user)
      assert :ok = Policy.authorize(:manage_step_link, user, link)
    end

    test "other user cannot manage someone else's link" do
      user = insert(:user)
      link = insert(:step_link)
      assert {:error, :unauthorized} = Policy.authorize(:manage_step_link, user, link)
    end

    test "nil link is unauthorized" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_step_link, user, nil)
    end
  end

  describe "authorize(:manage_sequence, user, sequence)" do
    test "admin can manage any sequence" do
      admin = insert(:admin)
      sequence = insert(:sequence)
      assert :ok = Policy.authorize(:manage_sequence, admin, sequence)
    end

    test "owner can manage their own sequence" do
      user = insert(:user)
      sequence = insert(:sequence, user: user)
      assert :ok = Policy.authorize(:manage_sequence, user, sequence)
    end

    test "other user cannot manage someone else's sequence" do
      user = insert(:user)
      sequence = insert(:sequence)
      assert {:error, :unauthorized} = Policy.authorize(:manage_sequence, user, sequence)
    end

    test "nil sequence is unauthorized" do
      user = insert(:user)
      assert {:error, :unauthorized} = Policy.authorize(:manage_sequence, user, nil)
    end
  end

  describe "authorized?/3" do
    test "mirrors authorize/3 as a boolean" do
      admin = insert(:admin)
      user = insert(:user)
      step = insert(:step)

      assert Policy.authorized?(:delete_step, admin, step)
      refute Policy.authorized?(:delete_step, user, step)
    end
  end

  describe "authorize(:broadcast_lesson, user, _)" do
    test "teacher publishes a lesson" do
      teacher = insert(:user, is_teacher: true)
      assert :ok = Policy.authorize(:broadcast_lesson, teacher, nil)
    end

    test "non-teacher does not publish a lesson" do
      user = insert(:user, is_teacher: false)
      assert {:error, :unauthorized} = Policy.authorize(:broadcast_lesson, user, nil)
    end
  end

  describe "authorize(:manage_lesson, user, lesson)" do
    test "only the owning teacher manages the lesson" do
      teacher = insert(:user, is_teacher: true)
      other = insert(:user, is_teacher: true)
      lesson = %OGrupoDeEstudos.Study.Lesson{teacher_id: teacher.id}

      assert :ok = Policy.authorize(:manage_lesson, teacher, lesson)
      assert {:error, :unauthorized} = Policy.authorize(:manage_lesson, other, lesson)
    end
  end

  describe "authorize(:view_workshop, user, workshop)" do
    test "published workshop opens for anyone, anonymous included" do
      workshop = %Workshop{organizer_id: insert(:user).id, status: :published}

      assert Policy.authorize(:view_workshop, nil, workshop) == :ok
      assert Policy.authorize(:view_workshop, insert(:user), workshop) == :ok
    end

    test "cancelled workshop stays readable: enrolled people need to know what happened" do
      workshop = %Workshop{organizer_id: insert(:user).id, status: :cancelled}

      assert Policy.authorize(:view_workshop, nil, workshop) == :ok
    end

    test "draft belongs to the organizer alone" do
      owner = insert(:user)
      workshop = %Workshop{organizer_id: owner.id, status: :draft}

      assert Policy.authorize(:view_workshop, owner, workshop) == :ok
      assert Policy.authorize(:view_workshop, nil, workshop) == {:error, :not_found}
      assert Policy.authorize(:view_workshop, insert(:user), workshop) == {:error, :not_found}
    end

    test "site admin does not enter someone else's draft" do
      workshop = %Workshop{organizer_id: insert(:user).id, status: :draft}

      assert Policy.authorize(:view_workshop, insert(:admin), workshop) == {:error, :not_found}
    end
  end

  describe "authorize(:create_workshop | :manage_workshop, ...)" do
    test "whoever teaches creates a workshop" do
      assert :ok = Policy.authorize(:create_workshop, insert(:user, is_teacher: true), nil)
    end

    test "a site admin creates one too, to help set the agenda up" do
      assert :ok = Policy.authorize(:create_workshop, insert(:admin), nil)
    end

    test "whoever only studies does not create one" do
      assert {:error, :unauthorized} =
               Policy.authorize(:create_workshop, insert(:user, is_teacher: false), nil)
    end

    test "a visitor is asked to log in, not told they lack permission" do
      assert {:error, :unauthenticated} = Policy.authorize(:create_workshop, nil, nil)
    end

    test "creating a program follows the same rule" do
      assert :ok = Policy.authorize(:create_program, insert(:user, is_teacher: true), nil)
      assert :ok = Policy.authorize(:create_program, insert(:admin), nil)
      assert {:error, :unauthenticated} = Policy.authorize(:create_program, nil, nil)

      assert {:error, :unauthorized} =
               Policy.authorize(:create_program, insert(:user, is_teacher: false), nil)
    end

    test "only the organizer manages it, not even a site admin" do
      organizer = insert(:user)
      workshop = %OGrupoDeEstudos.Workshops.Workshop{organizer_id: organizer.id}

      assert :ok = Policy.authorize(:manage_workshop, organizer, workshop)
      assert {:error, :unauthorized} = Policy.authorize(:manage_workshop, insert(:user), workshop)

      assert {:error, :unauthorized} =
               Policy.authorize(:manage_workshop, insert(:admin), workshop)
    end
  end
end

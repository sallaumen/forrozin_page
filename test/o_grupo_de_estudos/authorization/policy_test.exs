defmodule OGrupoDeEstudos.Authorization.PolicyTest do
  use OGrupoDeEstudos.DataCase, async: true
  import OGrupoDeEstudos.Factory
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.Workshop

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
    test "professor pode enviar lição" do
      teacher = insert(:user, is_teacher: true)
      assert :ok = Policy.authorize(:broadcast_lesson, teacher, nil)
    end

    test "quem não é professor não pode" do
      user = insert(:user, is_teacher: false)
      assert {:error, :unauthorized} = Policy.authorize(:broadcast_lesson, user, nil)
    end
  end

  describe "authorize(:manage_lesson, user, lesson)" do
    test "só o professor dono gerencia a lição" do
      teacher = insert(:user, is_teacher: true)
      other = insert(:user, is_teacher: true)
      lesson = %OGrupoDeEstudos.Study.Lesson{teacher_id: teacher.id}

      assert :ok = Policy.authorize(:manage_lesson, teacher, lesson)
      assert {:error, :unauthorized} = Policy.authorize(:manage_lesson, other, lesson)
    end
  end

  describe "authorize(:view_workshop, user, workshop)" do
    test "publicado abre para qualquer um, inclusive sem conta" do
      workshop = %Workshop{organizer_id: insert(:user).id, status: :published}

      assert Policy.authorize(:view_workshop, nil, workshop) == :ok
      assert Policy.authorize(:view_workshop, insert(:user), workshop) == :ok
    end

    test "cancelado continua legível: quem se inscreveu precisa saber o que houve" do
      workshop = %Workshop{organizer_id: insert(:user).id, status: :cancelled}

      assert Policy.authorize(:view_workshop, nil, workshop) == :ok
    end

    test "rascunho é só de quem organiza" do
      dono = insert(:user)
      workshop = %Workshop{organizer_id: dono.id, status: :draft}

      assert Policy.authorize(:view_workshop, dono, workshop) == :ok
      assert Policy.authorize(:view_workshop, nil, workshop) == {:error, :not_found}
      assert Policy.authorize(:view_workshop, insert(:user), workshop) == {:error, :not_found}
    end

    test "admin do site não entra no rascunho alheio" do
      # Mesma regra de :manage_workshop: workshop é do organizador, não da casa.
      workshop = %Workshop{organizer_id: insert(:user).id, status: :draft}

      assert Policy.authorize(:view_workshop, insert(:admin), workshop) == {:error, :not_found}
    end
  end

  describe "authorize(:create_workshop | :manage_workshop, ...)" do
    test "qualquer usuário logado cria workshop" do
      assert :ok = Policy.authorize(:create_workshop, insert(:user, is_teacher: false), nil)
      assert {:error, :unauthenticated} = Policy.authorize(:create_workshop, nil, nil)
    end

    test "só o organizador gerencia, nem admin entra" do
      organizer = insert(:user)
      workshop = %OGrupoDeEstudos.Workshops.Workshop{organizer_id: organizer.id}

      assert :ok = Policy.authorize(:manage_workshop, organizer, workshop)
      assert {:error, :unauthorized} = Policy.authorize(:manage_workshop, insert(:user), workshop)

      assert {:error, :unauthorized} =
               Policy.authorize(:manage_workshop, insert(:admin), workshop)
    end
  end
end

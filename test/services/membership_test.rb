require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @section = Section.create!(user: @user, name: "S")
    @b = Question.create!(user: @user, name: "b", question_type: "number")
    @a = Question.create!(user: @user, name: "A", question_type: "number")
  end

  test "adds at the end and won't add twice" do
    assert Membership.add(:section_questions, @section, @b)
    assert Membership.add(:section_questions, @section, @a)
    refute Membership.add(:section_questions, @section, @a)
    assert_equal [ @b, @a ], @section.reload.questions.to_a
  end

  test "moves, sorts case-insensitively, and removes" do
    Membership.add(:section_questions, @section, @b)
    Membership.add(:section_questions, @section, @a)

    Membership.move(:section_questions, @section, @a.id, :up)
    assert_equal [ @a, @b ], @section.reload.questions.to_a

    Membership.sort(:section_questions, @section, "name", "desc")
    assert_equal [ @b, @a ], @section.reload.questions.to_a

    assert Membership.remove(:section_questions, @section, @b)
    refute Membership.remove(:section_questions, @section, @b)
    assert_equal [ @a ], @section.reload.questions.to_a
  end

  test "only sorts by name or created_at" do
    assert_raises(Membership::Error) { Membership.sort(:section_questions, @section, "destroy", "asc") }
  end

  test "moving an unlinked child is an error" do
    assert_raises(Membership::Error) { Membership.move(:section_questions, @section, @a.id, :down) }
  end
end

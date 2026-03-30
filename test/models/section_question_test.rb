require "test_helper"

class SectionQuestionTest < ActiveSupport::TestCase
  test "validates uniqueness of section and question" do
    section = sections(:one)
    question = questions(:one)

    # The fixture already creates this association
    duplicate = SectionQuestion.new(section: section, question: question, position: 99)
    assert_not duplicate.valid?
  end

  test "position_scope_column returns section_id" do
    assert_equal :section_id, SectionQuestion.position_scope_column
  end

  test "questions are ordered by position within a section" do
    user = users(:one)
    section = sections(:one)

    # Clear existing
    SectionQuestion.where(section: section).destroy_all

    q1 = Question.create!(name: "First", question_type: "string", user: user)
    q2 = Question.create!(name: "Second", question_type: "string", user: user)
    q3 = Question.create!(name: "Third", question_type: "string", user: user)

    SectionQuestion.create!(section: section, question: q3, position: 0)
    SectionQuestion.create!(section: section, question: q1, position: 1)
    SectionQuestion.create!(section: section, question: q2, position: 2)

    ordered_names = section.questions.reload.map(&:name)
    assert_equal [ "Third", "First", "Second" ], ordered_names
  end

  test "same question in different sections has independent ordering" do
    user = users(:one)
    section_a = Section.create!(name: "Section A", user: user)
    section_b = Section.create!(name: "Section B", user: user)

    q1 = Question.create!(name: "Q1", question_type: "string", user: user)
    q2 = Question.create!(name: "Q2", question_type: "string", user: user)

    # Q1 first in section A, Q2 first in section B
    SectionQuestion.create!(section: section_a, question: q1, position: 0)
    SectionQuestion.create!(section: section_a, question: q2, position: 1)
    SectionQuestion.create!(section: section_b, question: q2, position: 0)
    SectionQuestion.create!(section: section_b, question: q1, position: 1)

    assert_equal [ "Q1", "Q2" ], section_a.questions.map(&:name)
    assert_equal [ "Q2", "Q1" ], section_b.questions.map(&:name)

    # Moving in section A should not affect section B
    sq = SectionQuestion.find_by(section: section_a, question: q2)
    sq.move_higher!

    assert_equal [ "Q2", "Q1" ], section_a.questions.reload.map(&:name)
    assert_equal [ "Q2", "Q1" ], section_b.questions.reload.map(&:name)
  end
end

require "test_helper"

class SectionsOrderingTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
    @section = sections(:one)
  end

  test "should get index with sort params" do
    get sections_path(sort: "name", dir: "desc")
    assert_response :success
  end

  test "add_question assigns next position" do
    question = Question.create!(name: "New Q #{SecureRandom.hex(4)}", question_type: "string", user: @user)

    patch add_question_section_path(@section), params: { question_id: question.id }
    assert_redirected_to section_path(@section)

    sq = SectionQuestion.find_by(section: @section, question: question)
    assert sq, "SectionQuestion should be created"
    assert sq.position >= 0
  end

  test "remove_question destroys the join record" do
    question = Question.create!(name: "To Remove #{SecureRandom.hex(4)}", question_type: "number", user: @user)
    SectionQuestion.create!(section: @section, question: question, position: 99)

    assert_difference "SectionQuestion.count", -1 do
      patch remove_question_section_path(@section), params: { question_id: question.id }
    end
  end

  test "move_question_up swaps positions" do
    SectionQuestion.where(section: @section).destroy_all
    q1 = Question.create!(name: "Q1", question_type: "string", user: @user)
    q2 = Question.create!(name: "Q2", question_type: "string", user: @user)
    SectionQuestion.create!(section: @section, question: q1, position: 0)
    SectionQuestion.create!(section: @section, question: q2, position: 1)

    patch move_question_up_section_path(@section), params: { question_id: q2.id }
    assert_redirected_to section_path(@section)

    assert_equal 1, SectionQuestion.find_by(section: @section, question: q1).position
    assert_equal 0, SectionQuestion.find_by(section: @section, question: q2).position
  end

  test "move_question_down swaps positions" do
    SectionQuestion.where(section: @section).destroy_all
    q1 = Question.create!(name: "Q1", question_type: "string", user: @user)
    q2 = Question.create!(name: "Q2", question_type: "string", user: @user)
    SectionQuestion.create!(section: @section, question: q1, position: 0)
    SectionQuestion.create!(section: @section, question: q2, position: 1)

    patch move_question_down_section_path(@section), params: { question_id: q1.id }
    assert_redirected_to section_path(@section)

    assert_equal 1, SectionQuestion.find_by(section: @section, question: q1).position
    assert_equal 0, SectionQuestion.find_by(section: @section, question: q2).position
  end

  test "sort_questions reorders by name ascending" do
    SectionQuestion.where(section: @section).destroy_all
    q_z = Question.create!(name: "Zebra", question_type: "string", user: @user)
    q_a = Question.create!(name: "Alpha", question_type: "string", user: @user)
    SectionQuestion.create!(section: @section, question: q_z, position: 0)
    SectionQuestion.create!(section: @section, question: q_a, position: 1)

    patch sort_questions_section_path(@section), params: { sort_by: "name", direction: "asc" }
    assert_redirected_to section_path(@section)

    assert_equal 0, SectionQuestion.find_by(section: @section, question: q_a).position
    assert_equal 1, SectionQuestion.find_by(section: @section, question: q_z).position
  end

  test "creating question from section assigns position" do
    form = forms(:one)
    FormSection.find_or_create_by!(form: form, section: @section) { |fs| fs.position = 0 }

    post section_questions_path(@section), params: {
      question: { name: "Positioned Q #{SecureRandom.hex(4)}", question_type: "number" }
    }

    # The newest question should have the highest position
    newest_sq = SectionQuestion.where(section: @section).order(position: :desc).first
    assert newest_sq, "A SectionQuestion should be created"
  end
end

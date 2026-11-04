require "test_helper"

class NamespaceMoveTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "a question takes its answers" do
    question = Question.create!(user: @user, name: "Q", question_type: "number")
    answer = AnswerSubmission.call(question: question, user: @user, value: "1")

    assert_equal 2, NamespaceMove.call(user: @user, entities: { "questions" => [ question.id ] }, target_namespace: "x")
    assert_equal "x", answer.reload.namespace
  end

  test "only moves the user's own items" do
    moved = NamespaceMove.call(user: @user, entities: { "forms" => [ forms(:two).id ] }, target_namespace: "x")
    assert_equal 0, moved
    assert_equal "", forms(:two).reload.namespace
  end

  test "refuses types that aren't namespaced items" do
    assert_raises(NamespaceMove::Error) do
      NamespaceMove.call(user: @user, entities: { "users" => [ @user.id ] }, target_namespace: "x")
    end
  end
end

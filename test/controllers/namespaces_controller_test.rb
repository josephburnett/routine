require "test_helper"

class NamespacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
  end

  test "should redirect index to root namespace" do
    get namespaces_path
    assert_redirected_to namespace_path("root")
  end

  test "should show root namespace" do
    get namespace_path("root")
    assert_response :success
  end

  test "should show namespace by name" do
    # Create a form with a namespace
    form = Form.create!(name: "Test Form", user: @user, namespace: "work")

    get namespace_path("work")
    assert_response :success
  end

  test "should return 404 for non-existent namespace" do
    get namespace_path("nonexistent")
    assert_redirected_to namespace_path("root")
    assert_equal "Namespace not found", flash[:alert]
  end

  # Test cascading moves for Forms
  test "moving a form should cascade to responses, sections, questions, and answers" do
    # Create a form with all related entities
    form = Form.create!(name: "Test Form", user: @user, namespace: "work")

    # Create responses for the form
    response1 = Response.create!(form: form, user: @user, namespace: "work")
    response2 = Response.create!(form: form, user: @user, namespace: "work")

    # Create sections and associate with form
    section1 = Section.create!(name: "Section 1", user: @user, namespace: "work")
    section2 = Section.create!(name: "Section 2", user: @user, namespace: "work")
    form.sections << section1
    form.sections << section2

    # Create questions and associate with sections
    question1 = Question.create!(name: "Question 1", question_type: "string", user: @user, namespace: "work")
    question2 = Question.create!(name: "Question 2", question_type: "number", user: @user, namespace: "work")
    section1.questions << question1
    section2.questions << question2

    # Create answers for questions
    answer1 = Answer.create!(question: question1, answer_type: "string", string_value: "test", user: @user, namespace: "work")
    answer2 = Answer.create!(question: question2, answer_type: "number", number_value: 1.5, user: @user, namespace: "work")

    # Create answers for responses
    answer3 = Answer.create!(question: question1, response: response1, answer_type: "string", string_value: "test", user: @user, namespace: "work")

    # Move the form to a new namespace
    post namespace_path("work"), params: {
      target_namespace: "archive",
      entities: {
        forms: [ form.id ]
      }
    }

    assert_redirected_to namespace_path("work")
    assert_match(/Successfully moved \d+ items? to archive/, flash[:notice])

    # Verify all entities moved to new namespace
    assert_equal "archive", form.reload.namespace
    assert_equal "archive", response1.reload.namespace
    assert_equal "archive", response2.reload.namespace
    assert_equal "archive", section1.reload.namespace
    assert_equal "archive", section2.reload.namespace
    assert_equal "archive", question1.reload.namespace
    assert_equal "archive", question2.reload.namespace
    assert_equal "archive", answer1.reload.namespace
    assert_equal "archive", answer2.reload.namespace
    assert_equal "archive", answer3.reload.namespace
  end

  # Test cascading moves for Sections
  test "moving a section should cascade to questions and answers" do
    # Create a standalone section
    section = Section.create!(name: "Standalone Section", user: @user, namespace: "personal")

    # Create questions and associate with section
    question1 = Question.create!(name: "Question 1", question_type: "string", user: @user, namespace: "personal")
    question2 = Question.create!(name: "Question 2", question_type: "bool", user: @user, namespace: "personal")
    section.questions << question1
    section.questions << question2

    # Create answers for questions
    answer1 = Answer.create!(question: question1, answer_type: "string", string_value: "test", user: @user, namespace: "personal")
    answer2 = Answer.create!(question: question2, answer_type: "bool", bool_value: true, user: @user, namespace: "personal")

    # Move the section to a new namespace
    post namespace_path("personal"), params: {
      target_namespace: "work",
      entities: {
        sections: [ section.id ]
      }
    }

    assert_redirected_to namespace_path("personal")
    assert_match(/Successfully moved \d+ items? to work/, flash[:notice])

    # Verify all entities moved
    assert_equal "work", section.reload.namespace
    assert_equal "work", question1.reload.namespace
    assert_equal "work", question2.reload.namespace
    assert_equal "work", answer1.reload.namespace
    assert_equal "work", answer2.reload.namespace
  end

  # Test cascading moves for Questions
  test "moving a question should cascade to answers" do
    # Create a standalone question
    question = Question.create!(name: "Standalone Question", question_type: "range", range_min: 1, range_max: 10, user: @user, namespace: "work")

    # Create answers for the question
    answer1 = Answer.create!(question: question, answer_type: "number", number_value: 5, user: @user, namespace: "work")
    answer2 = Answer.create!(question: question, answer_type: "number", number_value: 7, user: @user, namespace: "work")

    # Move the question to a new namespace
    post namespace_path("work"), params: {
      target_namespace: "archive",
      entities: {
        questions: [ question.id ]
      }
    }

    assert_redirected_to namespace_path("work")
    assert_match(/Successfully moved \d+ items? to archive/, flash[:notice])

    # Verify all entities moved
    assert_equal "archive", question.reload.namespace
    assert_equal "archive", answer1.reload.namespace
    assert_equal "archive", answer2.reload.namespace
  end

  # Test that Metrics, Alerts, Reports don't cascade
  test "moving metrics should not cascade to alerts or reports" do
    # Create metric, alert, and report
    metric = Metric.create!(name: "Test Metric", user: @user, namespace: "work", resolution: "day", width: "daily", function: "sum")
    alert = Alert.create!(name: "Test Alert", metric: metric, user: @user, namespace: "work", direction: "above", threshold: 100, delay: 1)
    report = Report.create!(name: "Test Report", user: @user, namespace: "work", interval_type: "none")

    # Move only the metric
    post namespace_path("work"), params: {
      target_namespace: "personal",
      entities: {
        metrics: [ metric.id ]
      }
    }

    assert_redirected_to namespace_path("work")

    # Verify only metric moved, alert stayed in original namespace
    assert_equal "personal", metric.reload.namespace
    assert_equal "work", alert.reload.namespace
    assert_equal "work", report.reload.namespace
  end

  # Test visibility: Answers should be hidden
  test "answers should not appear in namespace entities" do
    # Create a question with answers
    question = Question.create!(name: "Question", question_type: "string", user: @user, namespace: "work")
    answer = Answer.create!(question: question, answer_type: "string", string_value: "test", user: @user, namespace: "work")

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Answers should not appear in entities hash
    assert_not entities.key?("Answers")
  end

  # Test visibility: Responses should be hidden
  test "responses should not appear in namespace entities" do
    # Create a form with a response
    form = Form.create!(name: "Form", user: @user, namespace: "work")
    response = Response.create!(form: form, user: @user, namespace: "work")

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Responses should not appear in entities hash
    assert_not entities.key?("Responses")
  end

  # Test visibility: Questions in sections should be hidden
  test "questions in sections should not appear in namespace entities" do
    # Create a section with a question
    section = Section.create!(name: "Section", user: @user, namespace: "work")
    question = Question.create!(name: "Question", question_type: "string", user: @user, namespace: "work")
    section.questions << question

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Question should not appear because it's in a section
    if entities.key?("Questions")
      assert_not entities["Questions"].include?(question), "Question should not be in entities when it belongs to a section"
    else
      # If Questions key doesn't exist, that's also correct (all questions are hidden)
      assert true
    end
  end

  # Test visibility: Standalone questions should appear
  test "standalone questions should appear in namespace entities" do
    # Create a standalone question (not in any section)
    question = Question.create!(name: "Standalone Question", question_type: "string", user: @user, namespace: "work")

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Question should appear because it's standalone
    assert entities.key?("Questions")
    assert entities["Questions"].include?(question)
  end

  # Test visibility: Sections in forms should be hidden
  test "sections in forms should not appear in namespace entities" do
    # Create a form with a section
    form = Form.create!(name: "Form", user: @user, namespace: "work")
    section = Section.create!(name: "Section", user: @user, namespace: "work")
    form.sections << section

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Section should not appear because it's in a form
    if entities.key?("Sections")
      assert_not entities["Sections"].include?(section), "Section should not be in entities when it belongs to a form"
    else
      # If Sections key doesn't exist, that's also correct (all sections are hidden)
      assert true
    end
  end

  # Test visibility: Standalone sections should appear
  test "standalone sections should appear in namespace entities" do
    # Create a standalone section (not in any form)
    section = Section.create!(name: "Standalone Section", user: @user, namespace: "work")

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    # Section should appear because it's standalone
    assert entities.key?("Sections")
    assert entities["Sections"].include?(section)
  end

  # Test visibility: Forms always appear
  test "forms should always appear in namespace entities" do
    form = Form.create!(name: "Test Form", user: @user, namespace: "work")

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    assert entities.key?("Forms")
    assert entities["Forms"].include?(form)
  end

  # Test visibility: Metrics, Alerts, Reports, Remembers always appear
  test "metrics alerts reports and remembers should always appear in namespace entities" do
    metric = Metric.create!(name: "Metric", user: @user, namespace: "work", resolution: "day", width: "daily", function: "sum")
    alert = Alert.create!(name: "Alert", metric: metric, user: @user, namespace: "work", direction: "above", threshold: 100, delay: 1)
    report = Report.create!(name: "Report", user: @user, namespace: "work", interval_type: "none")
    remember = Remember.create!(description: "Remember", user: @user, namespace: "work", state: "floating", decay: 0.5)

    namespace = Namespace.find_for_user(@user, "work")
    entities = namespace.entities

    assert entities.key?("Metrics")
    assert entities["Metrics"].include?(metric)
    assert entities.key?("Alerts")
    assert entities["Alerts"].include?(alert)
    assert entities.key?("Reports")
    assert entities["Reports"].include?(report)
    assert entities.key?("Remembers")
    assert entities["Remembers"].include?(remember)
  end

  # Test moving Remembers
  test "moving remembers should work independently without cascading" do
    remember = Remember.create!(description: "Test Remember", user: @user, namespace: "work", state: "floating", decay: 0.5)

    # Move the remember to a new namespace
    post namespace_path("work"), params: {
      target_namespace: "personal",
      entities: {
        remembers: [ remember.id ]
      }
    }

    assert_redirected_to namespace_path("work")
    assert_match(/Successfully moved 1 item to personal/, flash[:notice])

    # Verify remember moved
    assert_equal "personal", remember.reload.namespace
  end

  # Test shared resources: Section in multiple forms
  test "moving form with shared section should move the section" do
    # Create two forms
    form1 = Form.create!(name: "Form 1", user: @user, namespace: "work")
    form2 = Form.create!(name: "Form 2", user: @user, namespace: "personal")

    # Create a section shared between both forms
    section = Section.create!(name: "Shared Section", user: @user, namespace: "work")
    form1.sections << section
    form2.sections << section

    # Move form1 to archive
    post namespace_path("work"), params: {
      target_namespace: "archive",
      entities: {
        forms: [ form1.id ]
      }
    }

    # Section should be moved to archive (even though it's still in form2)
    assert_equal "archive", section.reload.namespace
    assert_equal "personal", form2.reload.namespace
  end

  # Test shared resources: Question in multiple sections
  test "moving section with shared question should move the question" do
    # Create two sections
    section1 = Section.create!(name: "Section 1", user: @user, namespace: "work")
    section2 = Section.create!(name: "Section 2", user: @user, namespace: "personal")

    # Create a question shared between both sections
    question = Question.create!(name: "Shared Question", question_type: "string", user: @user, namespace: "work")
    section1.questions << question
    section2.questions << question

    # Move section1 to archive
    post namespace_path("work"), params: {
      target_namespace: "archive",
      entities: {
        sections: [ section1.id ]
      }
    }

    # Question should be moved to archive (even though it's still in section2)
    assert_equal "archive", question.reload.namespace
    assert_equal "personal", section2.reload.namespace
  end

  # Test moving to root namespace
  test "should move items to root namespace when target is empty" do
    form = Form.create!(name: "Form", user: @user, namespace: "work")

    post namespace_path("work"), params: {
      target_namespace: "",
      entities: {
        forms: [ form.id ]
      }
    }

    assert_redirected_to namespace_path("work")
    assert_match(/Successfully moved \d+ items? to Root/, flash[:notice])
    assert_equal "", form.reload.namespace
  end

  # Test moving with no items selected
  test "should show error when no items selected for moving" do
    post namespace_path("root"), params: {
      target_namespace: "work",
      entities: {}
    }

    assert_redirected_to namespace_path("root")
    assert_equal "No items were selected for moving", flash[:alert]
  end
end

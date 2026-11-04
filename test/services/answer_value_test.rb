require "test_helper"

class AnswerValueTest < ActiveSupport::TestCase
  test "casts web form values per question type" do
    assert_equal({ string_value: "hi" }, AnswerValue.attributes_for("string", "hi"))
    assert_equal({ number_value: 2.5 }, AnswerValue.attributes_for("number", "2.5"))
    assert_equal({ number_value: 3.0 }, AnswerValue.attributes_for("range", "3"))
    assert_equal({ bool_value: true }, AnswerValue.attributes_for("bool", "1"))
    assert_equal({ bool_value: false }, AnswerValue.attributes_for("bool", "0"))
    assert_equal({}, AnswerValue.attributes_for("unknown", "x"))
  end
end

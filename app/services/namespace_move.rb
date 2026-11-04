# Moves items to another namespace. Unless cascade is off, related items move
# too: a form takes its responses, their answers, its sections, their questions
# and those questions' answers; a section takes its questions and their
# answers; a question takes its answers.
module NamespaceMove
  MODELS = {
    "forms" => Form, "sections" => Section, "questions" => Question,
    "answers" => Answer, "responses" => Response, "metrics" => Metric,
    "alerts" => Alert, "reports" => Report, "remembers" => Remember
  }.freeze

  class Error < StandardError; end

  module_function

  # entities: { "forms" => [ids], "questions" => [ids], ... }
  # Returns the number of items moved, including cascaded ones.
  def call(user:, entities:, target_namespace:, cascade: true)
    target = target_namespace.to_s
    count = 0

    ActiveRecord::Base.transaction do
      entities.to_h.each do |type, ids|
        next if ids.blank?

        model = MODELS.fetch(type.to_s.pluralize) { raise Error, "Can't move #{type}" }
        model.where(id: Array(ids), user: user).find_each do |entity|
          count += move(entity, target, cascade)
        end
      end
    end

    count
  end

  def move(entity, target, cascade)
    entity.update!(namespace: target)
    count = 1
    return count unless cascade

    case entity
    when Form
      entity.responses.each do |response|
        count += move(response, target, false)
        response.answers.each { |answer| count += move(answer, target, false) }
      end
      entity.sections.each { |section| count += move(section, target, true) }
    when Section
      entity.questions.each { |question| count += move(question, target, true) }
    when Question
      entity.answers.each { |answer| count += move(answer, target, false) }
    end

    count
  end
end

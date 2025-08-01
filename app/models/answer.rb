class Answer < ApplicationRecord
  include Namespaceable

  belongs_to :question
  belongs_to :response, optional: true
  belongs_to :user, optional: true

  validates :answer_type, presence: true, inclusion: { in: %w[string number bool range] }
  validates :string_value, presence: true, if: -> { answer_type == "string" }
  validates :number_value, presence: true, if: -> { answer_type == "number" || answer_type == "range" }
  validates :bool_value, inclusion: { in: [ true, false ] }, if: -> { answer_type == "bool" }

  scope :not_deleted, -> { where(deleted: false) }

  after_create :invalidate_dependent_caches
  after_update :invalidate_dependent_caches
  after_destroy :invalidate_dependent_caches

  def soft_delete!
    update!(deleted: true)
  end

  def value
    case answer_type
    when "string"
      string_value
    when "number", "range"
      number_value
    when "bool"
      bool_value
    end
  end

  def value=(val)
    case answer_type
    when "string"
      self.string_value = val
    when "number", "range"
      self.number_value = val
    when "bool"
      self.bool_value = val
    end
  end

  def display_title
    formatted_value = case answer_type
    when "bool"
      value ? "Yes" : "No"
    when "number", "range"
      value.round(2).to_s.gsub(/\.0+$/, "") # Remove trailing zeros
    else
      value.to_s
    end

    "#{question.name}: #{formatted_value}"
  end

  def display_name
    "#{display_title} (#{created_at.strftime('%Y-%m-%d')})"
  end

  private

  def invalidate_dependent_caches
    MetricDependencyService.invalidate_caches_for(self)
  end
end

class Question < ApplicationRecord
  include Namespaceable

  validates :name, presence: true
  validates :question_type, presence: true, inclusion: { in: %w[string number bool range] }
  validates :range_min, :range_max, presence: true, if: -> { question_type == "range" }
  validate :range_min_less_than_max, if: -> { question_type == "range" }

  belongs_to :user, optional: true
  has_and_belongs_to_many :sections
  has_many :answers

  # Reverse association to see which metrics reference this question
  has_many :metric_questions, dependent: :destroy
  has_many :metrics, through: :metric_questions

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end

  def range_options
    return [] unless question_type == "range" && range_min && range_max
    (range_min.to_i..range_max.to_i).to_a
  end

  def in_any_section?
    sections.exists?
  end

  private

  def range_min_less_than_max
    return unless range_min && range_max
    errors.add(:range_max, "must be greater than range_min") if range_max <= range_min
  end
end

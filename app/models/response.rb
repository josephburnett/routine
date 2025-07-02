class Response < ApplicationRecord
  include Namespaceable

  belongs_to :form
  belongs_to :user, optional: true
  has_many :answers
  accepts_nested_attributes_for :answers, allow_destroy: true

  scope :not_deleted, -> { where(deleted: false) }

  # Cascade datetime changes to all associated answers
  after_update :cascade_datetime_to_answers, if: :saved_change_to_created_at?

  def soft_delete!
    transaction do
      answers.not_deleted.each(&:soft_delete!)
      update!(deleted: true)
    end
  end

  # Update response timestamp and cascade to all answers
  def update_timestamp!(new_datetime)
    transaction do
      time_diff = new_datetime - created_at

      # Update the response timestamp
      update!(created_at: new_datetime, updated_at: Time.current)

      # Update all associated answers with the same time difference
      answers.not_deleted.each do |answer|
        answer.update!(created_at: answer.created_at + time_diff, updated_at: Time.current)
      end
    end
  end

  private

  def cascade_datetime_to_answers
    return unless created_at_previously_changed?

    old_time, new_time = created_at_previously_changed?
    time_diff = new_time - old_time

    answers.not_deleted.each do |answer|
      answer.update!(created_at: answer.created_at + time_diff, updated_at: Time.current)
    end
  end
end

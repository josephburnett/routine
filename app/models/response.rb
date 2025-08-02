class Response < ApplicationRecord
  include Namespaceable

  belongs_to :form
  belongs_to :user, optional: true
  has_many :answers
  accepts_nested_attributes_for :answers, allow_destroy: true

  scope :not_deleted, -> { where(deleted: false) }

  after_create :invalidate_dependent_caches
  after_update :invalidate_dependent_caches
  after_destroy :invalidate_dependent_caches

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
    return unless new_datetime && created_at

    transaction do
      time_diff = new_datetime - created_at

      # Update the response timestamp
      update!(created_at: new_datetime, updated_at: Time.current)

      # Update all associated answers with the same time difference
      answers.not_deleted.each do |answer|
        next unless answer.created_at
        answer.update!(created_at: answer.created_at + time_diff, updated_at: Time.current)
      end
    end
  end

  private

  def cascade_datetime_to_answers
    return unless created_at_previously_changed?

    old_time, new_time = created_at_previously_changed?
    
    # Guard against nil values that can cause NoMethodError
    return unless old_time && new_time
    
    time_diff = new_time - old_time

    answers.not_deleted.each do |answer|
      next unless answer.created_at
      answer.update!(created_at: answer.created_at + time_diff, updated_at: Time.current)
    end
  end

  def invalidate_dependent_caches
    MetricDependencyService.invalidate_caches_for(self)
  end
end

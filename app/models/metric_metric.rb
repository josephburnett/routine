class MetricMetric < ApplicationRecord
  include Positionable

  belongs_to :parent_metric, class_name: "Metric"
  belongs_to :child_metric, class_name: "Metric"

  validates :parent_metric_id, presence: true
  validates :parent_metric_id, uniqueness: { scope: :child_metric_id }
  validate :prevent_self_reference

  def self.position_scope_column
    :parent_metric_id
  end

  private

  def prevent_self_reference
    if parent_metric_id == child_metric_id
      errors.add(:child_metric, "cannot reference itself")
    end
  end
end

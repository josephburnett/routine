class MetricQuestion < ApplicationRecord
  include Positionable

  belongs_to :metric
  belongs_to :question

  def self.position_scope_column
    :metric_id
  end
end

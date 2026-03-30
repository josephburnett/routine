class ReportMetric < ApplicationRecord
  include Positionable

  belongs_to :report
  belongs_to :metric

  def self.position_scope_column
    :report_id
  end
end

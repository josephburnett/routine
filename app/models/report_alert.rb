class ReportAlert < ApplicationRecord
  include Positionable

  belongs_to :report
  belongs_to :alert

  def self.position_scope_column
    :report_id
  end
end

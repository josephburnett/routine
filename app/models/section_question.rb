class SectionQuestion < ApplicationRecord
  include Positionable

  belongs_to :section
  belongs_to :question

  validates :section_id, uniqueness: { scope: :question_id }

  def self.position_scope_column
    :section_id
  end
end

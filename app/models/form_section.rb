class FormSection < ApplicationRecord
  include Positionable

  belongs_to :form
  belongs_to :section

  validates :form_id, uniqueness: { scope: :section_id }

  def self.position_scope_column
    :form_id
  end
end

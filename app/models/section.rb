class Section < ApplicationRecord
  include Namespaceable

  validates :name, presence: true

  belongs_to :user, optional: true
  has_many :section_questions, -> { order(:position) }, dependent: :destroy
  has_many :questions, through: :section_questions
  has_many :form_sections, dependent: :destroy
  has_many :forms, through: :form_sections

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end

  def attached_to_any_form?
    forms.exists?
  end
end

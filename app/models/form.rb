class Form < ApplicationRecord
  include Namespaceable

  validates :name, presence: true

  belongs_to :user, optional: true
  has_many :form_sections, -> { order(:position) }, dependent: :destroy
  has_many :sections, through: :form_sections
  has_many :responses
  has_many :form_drafts, dependent: :destroy

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end
end

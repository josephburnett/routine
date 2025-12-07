class Section < ApplicationRecord
  include Namespaceable

  validates :name, presence: true

  belongs_to :user, optional: true
  has_and_belongs_to_many :questions
  has_and_belongs_to_many :forms

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end

  def attached_to_any_form?
    forms.exists?
  end
end

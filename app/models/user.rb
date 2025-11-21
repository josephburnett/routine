class User < ApplicationRecord
  has_secure_password

  validates :name, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_many :forms
  has_many :questions
  has_many :sections
  has_many :answers
  has_many :responses
  has_many :metrics
  has_many :alerts
  has_many :reports
  has_many :remembers
  has_one :user_setting, dependent: :destroy
end

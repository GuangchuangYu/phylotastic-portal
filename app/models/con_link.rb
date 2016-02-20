class ConLink < ActiveRecord::Base
  belongs_to :user

  has_one :raw_extraction, as: :contributable, dependent: :destroy
  
  validates :user_id, presence: true
  # TODO: format url
  validates :uri, presence: true
end

# app/models/app_setting.rb
class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  serialize :value, JSON
end

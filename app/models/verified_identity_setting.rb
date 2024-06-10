# == Schema Information
#
# Table name: verified_identity_settings
#
#  id                       :bigint(8)        not null, primary key
#  service_name             :string
#  private_key              :string
#  enable_verified_identity :boolean
#  enable_unknown_badge     :boolean
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
class VerifiedIdentitySetting < ApplicationRecord
end

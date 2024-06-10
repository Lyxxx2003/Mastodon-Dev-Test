class CreateVerifiedIdentitySettings < ActiveRecord::Migration[7.1]
  def change
    create_table :verified_identity_settings do |t|
      t.string :service_name
      t.string :private_key
      t.boolean :enable_verified_identity
      t.boolean :enable_unknown_badge

      t.timestamps
    end
  end
end

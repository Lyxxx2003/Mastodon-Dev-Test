# app/controllers/admin/verified_identity_controller.rb
module Admin
  class VerifiedIdentityController < ApplicationController
  	layout 'admin', only: [:index]
    def index
      render 'admin/verified_identity/index'
    end
  end
end

class Admin::VerifiedIdentityController < ApplicationController
  layout 'admin'

  before_action :set_verified_identity_setting, only: [:show]

  def index
    @verified_identity_setting = VerifiedIdentitySetting.new
    @verified_identities = VerifiedIdentitySetting.all
  end

  def show
  end

  def create
    Rails.logger.debug "Received parameters: #{params.inspect}" # Log parameters
    @verified_identity_setting = VerifiedIdentitySetting.new(verified_identity_params)
    if @verified_identity_setting.save
      redirect_to admin_verified_identity_show_path(@verified_identity_setting), notice: 'Settings were successfully saved.'
    else
      @verified_identities = VerifiedIdentitySetting.all
      render :index
    end
  end

  private

  def set_verified_identity_setting
    @verified_identity_setting = VerifiedIdentitySetting.find(params[:id])
  end

  def verified_identity_params
    params.require(:verified_identity_setting).permit(:service_name, :private_key, :enable_verified_identity, :enable_unknown_badge)
  end
end


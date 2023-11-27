# frozen_string_literal: true

module Admin
  class SettingsController < BaseController
    def show
      authorize :settings, :show?

      @admin_settings = Form::AdminSettings.new
    end

    def update
      puts "Update action called!"
      if @account.update(verifications_params)
        redirect_to settings_verification_path, notice: 'Successfully updated.'
      else
        flash[:error] = 'Error saving changes. Please try again.'
        render :show
      end
    end

    private

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end
  end
end

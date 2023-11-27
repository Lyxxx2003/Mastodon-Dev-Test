# frozen_string_literal: true

class Settings::VerificationsController < Settings::BaseController
  before_action :set_account

  def show
    @verified_links = @account.fields.select(&:verified?)

    service_name = "cryptoniteventures"
    private_key = "z24acdhznmlocpop4embib4fj3hrkeaqv3oadt3dykuvln4ghqka"

    profile_url = "https://truanon.com/api/get_profile?id=#{@account.username}&service=#{service_name}"
    Rails.logger.info('URL confirmation link...' + profile_url)

    # Create an HTTP object
    uri = URI.parse(profile_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    # Create a request
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = private_key

    response = http.request(request)
    profile_data = JSON.parse(response.body)

    if profile_data['type'] == 'error' && profile_data['title'] == 'Member Unknown'
      # Unknown so we are going to fetch a token and build a smart confirmation link
      # <a href=@verify_url target=ta-popup width=480, height=820, top=327.5, left=530>
      token_url = "https://truanon.com/api/get_token?id=#{@account.username}&service=#{service_name}"
      # Create an HTTP object
      uri = URI.parse(token_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Create a request
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Authorization'] = private_key

      response = http.request(request)
      token_data = JSON.parse(response.body)
      verify_token = token_data["id"]
      @verify_url = "https://truanon.com/api/verifyProfile?id=#{@account.username}&service=#{service_name}&token=#{verify_token}"

      # {"id":"j4kabvsnd27eq","type":"Proof","active":true,"name":"New Proof"}
      Rails.logger.info('verify_url from verify ' + @verify_url)
    else
      Rails.logger.info('Member is found...')
    end
  end

  def update
    if UpdateAccountService.new.call(@account, account_params.except(:settings))
      current_user.update!(settings_attributes: account_params[:settings])
      ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
      redirect_to settings_verification_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  def load_user_settings
    @user = User.find_by(username: params[:username])
    @user_settings = @user&.settings
  end

  private

  def account_params
    params.require(:account).permit(:discoverable, :unlocked, :indexable, :show_collections, settings: UserSettings.keys)
  end

  def set_account
    @account = current_account
  end

end

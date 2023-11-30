# app/services/tru_anon_service.rb
class TruAnonService
  def initialize(account)
    @account = account
    @service_name = ENV['TRU_ANON_SERVICE_NAME']
    @private_key = ENV['TRU_ANON_PRIVATE_KEY']

    if @service_name.blank? || @private_key.blank?
      raise StandardError, 'TRU_ANON_SERVICE_NAME and TRU_ANON_PRIVATE_KEY must be set'
    end
  end

  def get_profile
    Rails.logger.info('get_profile ' + @account.username)
    profile_url = "https://truanon.com/api/get_profile?id=#{@account.username}&service=#{@service_name}"
    perform_request(profile_url)
  end

  def verify_user
    profile_data = get_profile
    Rails.logger.info('verify_user ' + @account.username)

    if profile_data['type'] == 'error' && profile_data['title'] == 'Member Unknown'
      token_url = "https://truanon.com/api/get_token?id=#{@account.username}&service=#{@service_name}"
      token_data = perform_request(token_url)
      verify_token = token_data["id"]
      @verify_url = "https://truanon.com/api/verifyProfile?id=#{@account.username}&service=#{@service_name}&token=#{verify_token}"

      Rails.logger.info('verify_url from verify ' + @verify_url)
    else
      Rails.logger.info('Member is found...')
      truanon_profile = profile_data['dataConfigurations']&.find { |config| config['dataPointName'] == 'TruAnon Profile' }
      @public_profile_url = truanon_profile['displayValue'] if truanon_profile
    end
  rescue StandardError => e
    Rails.logger.error("TruAnonService error: #{e.message}")
  end

  def get_verify_url
    @verify_url
  end

  def get_public_profile_url
    @public_profile_url
  end

  private

  def perform_request(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = @private_key

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("TruAnonService HTTP request error: #{e.message}")
    {}
  end
end

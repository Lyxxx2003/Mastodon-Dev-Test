# app/services/truanon_service.rb 
class TruAnonService
  def initialize(account)
    @account = account
    @service_name = ENV['TRUANON_SERVICE_NAME']
    @private_key = ENV['TRUANON_PRIVATE_KEY']

    if @service_name.blank? || @private_key.blank?
      raise StandardError, 'TRUANON_SERVICE_NAME and TRUANON_PRIVATE_KEY must be set'
    end
  end

  def get_profile
    Rails.logger.info('get_profile ' + @account.username)
    profile_url = "https://truanon.com/api/get_profile?id=#{@account.username}&service=#{@service_name}"
    profile_data = perform_request(profile_url)

    @profile_data = process_profile_data(profile_data)

    generate_truanon_data
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

  # Create a helper method to generate TruAnon data
  def generate_truanon_data
    user_settings = @account.user.settings
    return unless @profile_data

    truanon_data = if @profile_data['type'] == 'error' || !user_settings.wants_verified_identity
      # Logic for error or when verified identity is off
      [
        {
          link: 'Ask this member to turn on verified identity',
          display_name: 'Unknown Identity',
          class_name: '',
          class_icon: '',
        }
      ]
    else
      # Logic for normal processing
      [
        {
          link: @profile_data['authorRank'] + ' ' + @profile_data['authorRankScore'] + ' of 5',
          display_name: 'Verified Identity',
          class_name: 'verified',
          class_icon: 'fa fa-check-circle',
        }
      ]
    end

    # Append additional data configurations if they exist
    if @profile_data['dataConfigurations']
      additional_data = @profile_data['dataConfigurations'].map do |config|
        {
          link: config['displayValue'],
          display_name: config['dataPointName'],
          class_name: 'verified',
          class_icon: 'fa fa-check-circle',
        }
      end
      truanon_data += additional_data
    end

    Rails.logger.debug("truanon_service Generated dataConfigurations data: #{truanon_data.inspect}") if Rails.env.development? || Rails.env.staging?
    truanon_data
  end

  def isValidURL(str)
    regex = /\A[^\s.]+(\.[^\s]+)+\z/
    !!(str =~ regex)
  end

  def render_truanon_data
    data_to_render = generate_truanon_data
    return '' unless data_to_render.present? && data_to_render.is_a?(Array)

    html_content = data_to_render.map do |data|
      next unless data.is_a?(Hash)

      link = CGI.escapeHTML(data[:link].to_s)
      display_name = CGI.escapeHTML(data[:display_name].to_s)
      class_name = CGI.escapeHTML(data[:class_name].to_s)
      class_icon = CGI.escapeHTML(data[:class_icon].to_s)

      "<dl class='#{class_name}'>
        <dt class='translate'>#{display_name}</dt>
        <dd class='translate'>
          <span><i class='#{class_icon}'></i></span>
          <span>#{link}</span>
        </dd>
      </dl>"
    end.join

    html_content.html_safe
  end

  private


  def process_profile_data(profile_data)
    user_settings = @account.user.settings

    if user_settings.wants_verified_identity
      social_configurations = user_settings.display_social_properties ? filter_data_configurations(profile_data, '', 'social') : []

      primary_configurations = []
      additional_configurations = []
      personal_configurations = []
      truanon_configurations = []

      if user_settings.display_verified_contact_information
        primary_configurations = filter_data_configurations(profile_data, '', 'primary')
        additional_configurations = filter_data_configurations(profile_data, '', 'additional')
      end

      if user_settings.display_your_public_identity_profile && !user_settings.display_social_properties
        truanon_configurations = filter_data_configurations(profile_data, 'truanon', 'social')
      else
        truanon_configurations = []
      end

      if user_settings.display_profile_information
        personal_configurations = filter_data_configurations(profile_data, '', 'personal')
        personal_configurations.reject! { |data| data['dataPointType'] == 'bio' }
        personal_configurations.reject! { |data| user_settings.omit_age && data['dataPointType'] == 'birthday' }
        personal_configurations.reject! { |data| user_settings.omit_location && data['dataPointType'] == 'location' }
        personal_configurations.reject! { |data| user_settings.omit_pronouns && data['dataPointType'] == 'gender' }
      end

      new_configurations = truanon_configurations + social_configurations + primary_configurations + additional_configurations + personal_configurations
      profile_data['dataConfigurations'] = new_configurations
    else
      profile_data['dataConfigurations'] = []
    end

    Rails.logger.info("truanon_service Processed profile data: #{profile_data}")
    profile_data
  end

  def filter_data_configurations(my_data, data_point_type, data_point_kind)
    return [] unless my_data && my_data['dataConfigurations']

    my_data['dataConfigurations'].select do |config|
      if !data_point_type.empty?
        config['dataPointType'] == data_point_type && config['dataPointKind'] == data_point_kind
      else
        config['dataPointKind'] == data_point_kind
      end
    end
  end

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

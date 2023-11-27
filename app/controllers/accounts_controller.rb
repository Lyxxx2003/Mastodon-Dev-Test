# frozen_string_literal: true

class AccountsController < ApplicationController
  PAGE_SIZE     = 20
  PAGE_SIZE_MAX = 200

  include AccountControllerConcern
  include SignatureAuthentication

  vary_by -> { public_fetch_mode? ? 'Accept, Accept-Language, Cookie' : 'Accept, Accept-Language, Cookie, Signature' }

  before_action :require_account_signature!, if: -> { request.format == :json && authorized_fetch_mode? }

  skip_around_action :set_locale, if: -> { [:json, :rss].include?(request.format&.to_sym) }
  skip_before_action :require_functional!, unless: :limited_federation_mode?

  def show
    respond_to do |format|
      format.html do
        @account = Account.find_by(username: params[:username])
        @user = @account.user
        @user_settings = @user.settings if @user.present?

        if @user_settings.wants_verified_identity
          # Do something when wants_verified_identity is true
          puts "Display public identity profile is enabled!"

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
            # Perform actions when member is unknown
            Rails.logger.info('Member is unknown. Fetching a key to make a smart confirmation link...')
          else
            Rails.logger.info('Member is found...')

            # Use the filter function
            social_configurations = []
            if @user_settings.display_your_public_identity_profile
              Rails.logger.info("display_your_public_identity_profile : #{profile_data}")

              if @user_settings.display_public_social_properties
                puts "display_public_social_properties."
                social_configurations = filter_data_configurations(profile_data, '', 'social')
              else
                puts "else display_public_social_properties."
                social_configurations = filter_data_configurations(profile_data, 'truanon', 'social')
                #truanon_only = filter_data_configurations(profile_data, 'truanon', 'social')
                #social_configurations = [truanon_only]
              end
            else
              puts "else display_your_public_identity_profile."
              if @user_settings.display_public_social_properties
                puts "display_public_social_properties."
                social_configurations = filter_data_configurations(profile_data, '', 'social')
                social_configurations.reject! { |profile_data| profile_data['dataPointType'] == 'truanon' }
              else
                puts "else display_public_social_properties."
              end
            end
            Rails.logger.info('social_configurations: ' + social_configurations.to_s)

            if @user_settings.display_verified_contact_information
              puts "display_verified_contact_information."
              primary_configurations = filter_data_configurations(profile_data, '', 'primary')
              additional_configurations = filter_data_configurations(profile_data, '', 'additional')
            else
              puts "else display_verified_contact_information."
              primary_configurations = []
              additional_configurations = []
            end
            Rails.logger.info('social_configurations: ' + social_configurations.to_s)

            if @user_settings.display_personal_information
              puts "display_personal_information."
              personal_configurations = filter_data_configurations(profile_data, '', 'personal')
              personal_configurations.reject! { |personal_configurations| personal_configurations['dataPointType'] == 'bio' }

              if @user_settings.omit_age
                personal_configurations.reject! { |personal_configurations| personal_configurations['dataPointType'] == 'birthday' }
              end

              if @user_settings.omit_location
                personal_configurations.reject! { |personal_configurations| personal_configurations['dataPointType'] == 'location' }
              end

              if @user_settings.omit_pronouns
                personal_configurations.reject! { |profile_data| profile_data['dataPointType'] == 'gender' }
              end

            else
              puts "else display_personal_information."
              personal_configurations = []
            end
            Rails.logger.info('social_configurations: ' + social_configurations.to_s)

            personal_configurations.reject! { |profile_data| profile_data['dataPointType'] == 'bio' }
            Rails.logger.info('social_configurations: ' + social_configurations.to_s)
            Rails.logger.info('personal_configurations: ' + personal_configurations.to_s)
            Rails.logger.info('primary_configurations: ' + primary_configurations.to_s)
            Rails.logger.info('additional_configurations: ' + additional_configurations.to_s)
            new_configurations = social_configurations + personal_configurations + primary_configurations + additional_configurations
            Rails.logger.info('new_configurations: ' + new_configurations.to_s)
            # Replace the dataConfigurations array in profile_data
            profile_data['dataConfigurations'] = new_configurations
            #puts new_configurations
            Rails.logger.info('profile_data: ' + profile_data.to_s)
            @profile_data = profile_data

          end
        else
          new_configurations = []

          @profile_data = { 'dataConfigurations' => new_configurations }

          puts "Display public identity profile is disabled or not set."
        end


        expires_in(15.seconds, public: true, stale_while_revalidate: 30.seconds, stale_if_error: 1.hour) unless user_signed_in?

        @rss_url = rss_url
      end

      def filter_data_configurations(my_data, data_point_type, data_point_kind)
        return [] unless my_data && my_data['dataConfigurations']

        my_data['dataConfigurations'].select do |profile_data|
          if !data_point_type.empty?
            profile_data['dataPointType'] == data_point_type && profile_data['dataPointKind'] == data_point_kind
          else
            profile_data['dataPointKind'] == data_point_kind
          end
        end
      end

      format.rss do
        expires_in 1.minute, public: true

        limit = params[:limit].present? ? [params[:limit].to_i, PAGE_SIZE_MAX].min : PAGE_SIZE
        @statuses = filtered_statuses.without_reblogs.limit(limit)
        @statuses = cache_collection(@statuses, Status)
      end

      format.json do
        expires_in 3.minutes, public: !(authorized_fetch_mode? && signed_request_account.present?)
        render_with_cache json: @account, content_type: 'application/activity+json', serializer: ActivityPub::ActorSerializer, adapter: ActivityPub::Adapter
      end
    end
  end

  private

  def filtered_statuses
    default_statuses.tap do |statuses|
      statuses.merge!(hashtag_scope)    if tag_requested?
      statuses.merge!(only_media_scope) if media_requested?
      statuses.merge!(no_replies_scope) unless replies_requested?
    end
  end

  def default_statuses
    @account.statuses.where(visibility: [:public, :unlisted])
  end

  def only_media_scope
    Status.joins(:media_attachments).merge(@account.media_attachments.reorder(nil)).group(:id)
  end

  def no_replies_scope
    Status.without_replies
  end

  def hashtag_scope
    tag = Tag.find_normalized(params[:tag])

    if tag
      Status.tagged_with(tag.id)
    else
      Status.none
    end
  end

  def username_param
    params[:username]
  end

  def skip_temporary_suspension_response?
    request.format == :json
  end

  def rss_url
    if tag_requested?
      short_account_tag_url(@account, params[:tag], format: 'rss')
    else
      short_account_url(@account, format: 'rss')
    end
  end

  def media_requested?
    request.path.split('.').first.end_with?('/media') && !tag_requested?
  end

  def replies_requested?
    request.path.split('.').first.end_with?('/with_replies') && !tag_requested?
  end

  def tag_requested?
    request.path.split('.').first.end_with?(Addressable::URI.parse("/tagged/#{params[:tag]}").normalize)
  end

  def cached_filtered_status_page
    cache_collection_paginated_by_id(
      filtered_statuses,
      Status,
      PAGE_SIZE,
      params_slice(:max_id, :min_id, :since_id)
    )
  end

  def params_slice(*keys)
    params.slice(*keys).permit(*keys)
  end
end

# frozen_string_literal: true

module HomeHelper
  def default_props
    {
      locale: I18n.locale,
    }
  end

  def account_link_to(account, additional_content = '', truanon_data: nil, path: nil)
    Rails.logger.debug("Render additional_content data Call stack: #{caller.join("\n")}")
    content_tag(:div, class: 'account account--minimal') do
      content_tag(:div, class: 'account__wrapper') do
        section = if account.nil?
                    # Render content for nil account
                  else
                    # Render content for a valid account
                    link_to(path || ActivityPub::TagManager.instance.url_for(account), class: 'account__display-name') do
                      content_tag(:div, class: 'account__avatar-wrapper') do
                        image_tag(full_asset_url(current_account&.user&.setting_auto_play_gif ? account.avatar_original_url : account.avatar_static_url), class: 'account__avatar', width: 46, height: 46)
                      end +
                        content_tag(:span, class: 'display-name') do
                          content_tag(:bdi) do
                            content_tag(:strong, display_name(account, custom_emojify: true), class: 'display-name__html emojify')
                          end +
                            content_tag(:span, "@#{account.acct}", class: 'display-name__account')
                        end +
                        render_truanon_data(truanon_data) # Render TruAnon data
                    end
                  end

        section + additional_content
      end
    end
  end

  # Create a helper method to generate TruAnon data
  def generate_truanon_data
    return unless @profile_data['dataConfigurations']

    truanon_data = @profile_data['dataConfigurations'].map do |config|
      {
        link: config['displayValue'],
        display_name: config['dataPointName'],
        # Add other properties as needed
      }
    end

    Rails.logger.debug("Generated dataConfigurations data: #{truanon_data.inspect}") if Rails.env.development? || Rails.env.staging?

    truanon_data
  end

  def isValidURL(str)
    regex = /\A[^\s.]+(\.[^\s]+)+\z/
    !!(str =~ regex)
  end

  def render_truanon_data(truanon_data)
    return '' unless truanon_data.present? && truanon_data.is_a?(Array)
    content_tag(:div, id: 'truanon-data-container') do
      content_tag(:dl, class: 'verified') do
        truanon_data.map do |data|
          next unless data.is_a?(Hash)

          Rails.logger.debug("Rendering TruAnon data for #{data.inspect}")

          begin
            link = h(data[:link]).html_safe
            display_name = h(data[:display_name]).html_safe

            content_tag(:dt, class: 'translate') { raw(display_name) } +
            content_tag(:dd, class: 'translate') do
              content_tag(:span) do
                content_tag(:i, '', class: 'fa fa-check-circle') +
                content_tag(:span) do
                  Rails.logger.debug("Link data: #{link}")
                  if isValidURL(link)
                    link_to(raw(link), 'https://' + link, target: '_blank', rel: 'nofollow noopener noreferrer', translate: 'no')
                  else
                    raw(link)
                  end
                end
              end
            end
          rescue => e
            Rails.logger.error("Error rendering TruAnon data: #{e.message}")
            Rails.logger.error("Data causing the error: #{data.inspect}")
            ''
          end
        end.join.html_safe
      end
    end
  end
  
  def obscured_counter(count)
    if count <= 0
      '0'
    elsif count == 1
      '1'
    else
      '1+'
    end
  end

  def custom_field_classes(field)
    field.verified? ? 'verified' : 'emojify'
  end

  def sign_up_message
    if closed_registrations?
      t('auth.registration_closed', instance: site_hostname)
    elsif open_registrations?
      t('auth.register')
    elsif approved_registrations?
      t('auth.apply_for_account')
    end
  end
end

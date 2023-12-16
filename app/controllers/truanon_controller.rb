class TruanonController < ApplicationController
  def profile
    account = Account.find(params[:id])
    truanon_service = TruAnonService.new(account)
    truanon_data = truanon_service.get_profile
    Rails.logger.debug("Truanon data received: #{truanon_data.inspect}")

    html_content = truanon_service.render_truanon_data
    Rails.logger.debug("Generated HTML content: #{html_content.inspect}")

    render html: html_content.html_safe
  end
end

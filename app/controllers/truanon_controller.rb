class TruanonController < ApplicationController
  def profile
    account = Account.find(params[:id])
    truanon_service = TruAnonService.new(account)
    truanon_data = truanon_service.get_profile
    render json: truanon_data
  end
end

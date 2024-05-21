class TestMailer < ApplicationMailer
    default from: ENV['SMTP_FROM_ADDRESS']

    def test_email(user)
      @user = user
      mail(to: @user.email, subject: 'Test Email')
    end
end
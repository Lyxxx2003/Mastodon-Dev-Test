class TestMailer < ApplicationMailer
    default from: ENV['SMTP_FROM_ADDRESS']

    def test_email
      mail(to: 'yl5574@columbia.edu', subject: 'Test Email', body: 'This is a test email.')
    end
end
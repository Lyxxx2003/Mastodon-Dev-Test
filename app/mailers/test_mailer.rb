class TestMailer < ApplicationMailer
    default from: ENV['SMTP_FROM_ADDRESS']

    def test_email
      mail(to: 'liyuxin031121@gmail.com', subject: 'Test Email', body: 'This is a test email.')
    end
end
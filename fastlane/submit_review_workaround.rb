require 'dotenv'
require 'spaceship'

Dotenv.load(File.expand_path('../.env', __dir__))

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'),
  issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'),
  key: ENV.fetch('APP_STORE_CONNECT_API_KEY_CONTENT')
)

bundle_id = 'com.entaku.VoiLog'
version_id = ENV.fetch('APP_STORE_VERSION_ID')

app = Spaceship::ConnectAPI::App.find(bundle_id)
raise "App not found for #{bundle_id}" unless app

submission = app.get_ready_review_submission(platform: 'IOS', includes: 'appStoreVersionForReview,items')
if submission.nil?
  puts 'No READY_FOR_REVIEW submission found, creating one...'
  submission = app.create_review_submission(platform: 'IOS')
end
puts "Review submission: #{submission.id} state=#{submission.state}"

begin
  puts "Adding app store version #{version_id} to review submission (no-op if already added)..."
  submission.add_app_store_version_to_review_items(app_store_version_id: version_id)
rescue Spaceship::UnexpectedResponse => e
  raise unless e.message.include?('was already added to this reviewSubmission')
  puts 'Version already added to this review submission, continuing...'
end

result = submission.submit_for_review
puts "Submitted for review. New state: #{result.state}"

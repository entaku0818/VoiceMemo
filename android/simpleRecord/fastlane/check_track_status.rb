require 'googleauth'
require 'google/apis/androidpublisher_v3'

AndroidPublisher = Google::Apis::AndroidpublisherV3

package_name = 'com.entaku.simpleRecord'
creds_json = ENV.fetch('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')
creds_io = StringIO.new(creds_json)

authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: creds_io,
  scope: ['https://www.googleapis.com/auth/androidpublisher']
)
authorizer.fetch_access_token!

service = AndroidPublisher::AndroidPublisherService.new
service.authorization = authorizer

edit = service.insert_edit(package_name, AndroidPublisher::AppEdit.new)
track = service.get_edit_track(package_name, edit.id, 'production')
puts "Track: production"
track.releases.each do |r|
  puts "  versionCodes=#{r.version_codes} status=#{r.status} userFraction=#{r.user_fraction} name=#{r.name}"
end

service.delete_edit(package_name, edit.id)

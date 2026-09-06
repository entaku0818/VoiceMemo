require 'googleauth'
require 'google/apis/androidpublisher_v3'

AndroidPublisher = Google::Apis::AndroidpublisherV3

package_name = 'com.entaku.simpleRecord'
version_code = ENV.fetch('VERSION_CODE').to_i
track_name = ENV.fetch('TRACK', 'production')

creds_json = ENV.fetch('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')
authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: StringIO.new(creds_json),
  scope: ['https://www.googleapis.com/auth/androidpublisher']
)
authorizer.fetch_access_token!

service = AndroidPublisher::AndroidPublisherService.new
service.authorization = authorizer

edit = service.insert_edit(package_name, AndroidPublisher::AppEdit.new)
puts "Edit created: #{edit.id}"

track = service.get_edit_track(package_name, edit.id, track_name)
release = track.releases.find { |r| r.version_codes.include?(version_code.to_s) }
raise "No release with versionCode #{version_code} found on #{track_name}" unless release

puts "Before: status=#{release.status} name=#{release.name}"
release.status = 'completed'
release.user_fraction = nil

updated_track = AndroidPublisher::Track.new(track: track_name, releases: [release])

begin
  service.update_edit_track(package_name, edit.id, track_name, updated_track)
  service.validate_edit(package_name, edit.id)
  service.commit_edit(package_name, edit.id)
  puts "Committed edit #{edit.id}. Release #{version_code} on #{track_name} set to completed."
rescue Google::Apis::ClientError => e
  puts "ClientError: #{e.status_code} #{e.body}"
  raise
end

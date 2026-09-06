require 'googleauth'
require 'google/apis/androidpublisher_v3'

# draft のまま作られたリリースを公開状態にする。
#
# `launchpad android rollout` は「Unexpected response format」で動かず、
# fastlane の upload_to_play_store は skip 系を全部立てると何もせず成功したように見えるだけなので、
# androidpublisher API を直接叩く。
#
#   VERSION_CODE=18 TRACK=production \
#     GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=$(cat fastlane/play-store-credentials.json) \
#     bundle exec ruby fastlane/complete_rollout.rb
#
# USER_FRACTION を渡すと段階公開（inProgress）になる。例: USER_FRACTION=0.2 で 20%。
# 省略時は completed（100%）。
#
# リリースノートは fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt から読む。
# `launchpad android upload` はノートを送らないため、ここで付けないと
# Play の「新機能」が空のまま公開されてしまう。

AndroidPublisher = Google::Apis::AndroidpublisherV3

package_name = 'com.entaku.simpleRecord'
version_code = ENV.fetch('VERSION_CODE').to_i
track_name = ENV.fetch('TRACK', 'production')
user_fraction = ENV['USER_FRACTION']&.to_f

metadata_root = File.expand_path('metadata/android', __dir__)

def load_release_notes(metadata_root, version_code)
  Dir.glob(File.join(metadata_root, '*', 'changelogs', "#{version_code}.txt")).sort.filter_map do |path|
    text = File.read(path).strip
    next if text.empty?

    language = File.basename(File.dirname(File.dirname(path)))
    AndroidPublisher::LocalizedText.new(language: language, text: text)
  end
end

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

puts "Before: status=#{release.status} name=#{release.name} notes=#{release.release_notes&.size || 0}"

notes = load_release_notes(metadata_root, version_code)
if notes.empty?
  warn "WARNING: no changelogs/#{version_code}.txt found under #{metadata_root} — publishing without release notes"
else
  puts "Attaching release notes: #{notes.map(&:language).join(', ')}"
  release.release_notes = notes
end

if user_fraction
  release.status = 'inProgress'
  release.user_fraction = user_fraction
  puts "Rolling out to #{(user_fraction * 100).round}% of users"
else
  release.status = 'completed'
  release.user_fraction = nil
  puts 'Rolling out to 100% of users'
end

# 既存の completed エントリを混ぜると 400 Invalid request になるため、対象1件だけを渡す
updated_track = AndroidPublisher::Track.new(track: track_name, releases: [release])

begin
  service.update_edit_track(package_name, edit.id, track_name, updated_track)
  service.validate_edit(package_name, edit.id)
  service.commit_edit(package_name, edit.id)
  puts "Committed edit #{edit.id}. Release #{version_code} on #{track_name} is now #{release.status}."
rescue Google::Apis::ClientError => e
  puts "ClientError: #{e.status_code} #{e.body}"
  raise
end

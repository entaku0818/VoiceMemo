#!/bin/sh

#  ci_post_clone.sh
#  VoiLog
#
#  Created by 遠藤拓弥 on 2024/03/30.
#  

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Rubyのバージョンを指定（必要に応じて変更してください）
rbenv install 3.2.2
rbenv global 3.2.2

# Bundlerのインストール
gem install bundler

# プロジェクトの依存関係をインストール
bundle install

# Fastlaneの実行
bundle exec fastlane upload_metadata

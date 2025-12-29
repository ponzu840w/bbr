# frozen_string_literal: true
source 'https://rubygems.org'

# プレビューサーバー用 (Ruby 3.0以降で必須)
gem 'webrick'

# JSONデータベース操作 (標準ライブラリですが、バージョン固定のため明記推奨)
gem 'json'

# --- 以下は開発・デバッグ用 (必須ではありませんがあると便利です) ---

group :development do
  # デバッグ用ツール (コードの途中で binding.pry と書くとそこで止めて変数を覗けます)
  gem 'pry'

  # コード整形・静的解析
  gem 'rubocop', require: false
end

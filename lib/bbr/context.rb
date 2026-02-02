require 'pathname'

# Context パスや環境変数などを保持する
module Bbr
  class Context
    attr_reader :repo_root, :system_root

    def initialize(repo_path = ENV['BBR_REPO'])
      unless repo_path
        raise "エラー: 環境変数 BBR_REPO が設定されていません。"
      end

      # リポジトリのルート
      @repo_root = Pathname.new(repo_path)

      # lib/bbr/context.rb から見たシステムルート (../../)
      @system_root = Pathname.new(__dir__).parent.parent
    end

    def articles_dir
      @repo_root.join('article')
    end

    def database_path
      @repo_root.join('database.json')
    end

    def current_num_file
      @repo_root.join('currentnum')
    end
  end
end

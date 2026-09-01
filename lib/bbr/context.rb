require 'pathname'

# Context パスや環境変数などを保持する
module Bbr
  class Context
    attr_reader :repo_root, :system_root

    def initialize(repo_path)
      raise ArgumentError, "Context: repo_path is required" if repo_path.nil?

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

    # マクロ定義は記事データではなくシステム側の資産
    def macro_file
      @system_root.join('html_article_define.m4')
    end
  end
end

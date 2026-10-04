class LambdadbMigration < Formula
  desc "Migrate vector databases and search systems into LambdaDB"
  homepage "https://github.com/lambdadb/lambdadb-migration"
  version "0.1.7"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.7/lambdadb-migration_0.1.7_darwin_amd64.tar.gz"
      sha256 "24492dd6a8298ef9ec136d5e7e08d4938d3bf0a262f55af5c47c6cb91aec3708"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.7/lambdadb-migration_0.1.7_darwin_arm64.tar.gz"
      sha256 "ef688d918b9382faaba897c7b7f496a21e1863d4c1d4c06dc06b31e6d88297bc"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.7/lambdadb-migration_0.1.7_linux_amd64.tar.gz"
      sha256 "04b03183e5014e1bb4d99a54899fcec46513dfb0f6b70e04f5cd4a3940525643"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.7/lambdadb-migration_0.1.7_linux_arm64.tar.gz"
      sha256 "f592ea61aa80dc71ef8093dff632bfff6acf00ae36df9c251bbcfce4b9ff5400"
    end
  end

  def install
    bin.install "lambdadb-migration"
    prefix.install "LICENSE", "NOTICE"
  end

  test do
    ENV.keys.grep(/^(LAMBDADB_|PINECONE_|ELASTIC_)/).each { |key| ENV.delete(key) }
    executable = bin/"lambdadb-migration"
    assert_match(/\A#{Regexp.escape(version.to_s)} \([0-9a-f]{40}\)\z/,
                 shell_output("#{executable} --version").strip)
    assert_match "Migrate vector/search data sources into LambdaDB.", shell_output("#{executable} --help")
    assert_match "inventory", shell_output("#{executable} inventory --help")
    %w[qdrant pinecone elasticsearch].each do |source|
      assert_match "--#{source}.", shell_output("#{executable} #{source} --help")
      assert_match "--#{source}.", shell_output("#{executable} inventory #{source} --help")
    end

    # Exercise connector construction, rejecting the URL before any network request.
    output = shell_output("#{executable} inventory elasticsearch --elasticsearch.index=homebrew-test " \
                          "--elasticsearch.url=invalid --output=#{testpath}/inventory.json 2>&1", 1)
    assert_match "parse elasticsearch url: missing scheme or host", output
    refute_path_exists testpath/"inventory.json"
  end
end

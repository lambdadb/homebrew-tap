class LambdadbMigration < Formula
  desc "Migrate vector databases and search systems into LambdaDB"
  homepage "https://github.com/lambdadb/lambdadb-migration"
  version "0.1.8"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.8/lambdadb-migration_0.1.8_darwin_amd64.tar.gz"
      sha256 "d7c92528a6fb079a4e4b98c432052c746b8fd7bf599e3ccd59f7972bda979c60"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.8/lambdadb-migration_0.1.8_darwin_arm64.tar.gz"
      sha256 "5d92932b6f2c386e9074d2b47a45043fa84dd08488bdda41809bca69e012695b"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.8/lambdadb-migration_0.1.8_linux_amd64.tar.gz"
      sha256 "38bc1e2251208e1da95af7ca3f6509010af9bff0fe4ab4ef7d5ac9d5e030e0ac"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.8/lambdadb-migration_0.1.8_linux_arm64.tar.gz"
      sha256 "3f4929eaac5a682c3fc56cfae4a627d2bc5246528f05d9c43555c3d083235e13"
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

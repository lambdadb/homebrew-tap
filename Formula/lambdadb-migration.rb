class LambdadbMigration < Formula
  desc "Migrate vector databases and search systems into LambdaDB"
  homepage "https://github.com/lambdadb/lambdadb-migration"
  version "0.1.9"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.9/lambdadb-migration_0.1.9_darwin_amd64.tar.gz"
      sha256 "ff7dfdbdeaf086af57244bcb65d4914022e1577f2974fe847ca7c153a99f94a1"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.9/lambdadb-migration_0.1.9_darwin_arm64.tar.gz"
      sha256 "0f400a6b6b4f4e27dfda4a8d132f036845a4a59845b2145718a8bc75d09ba31a"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.9/lambdadb-migration_0.1.9_linux_amd64.tar.gz"
      sha256 "2952d0a9188c9fe38e5bce9374123906798ec1da96ae1e30f6400825193d8ddc"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.9/lambdadb-migration_0.1.9_linux_arm64.tar.gz"
      sha256 "30f8881e3a49716aa3fb8353800378f4c9f84ddc36e24c1046d9481ca3db387b"
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

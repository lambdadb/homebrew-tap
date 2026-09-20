class LambdadbMigration < Formula
  desc "Migrate vector databases and search systems into LambdaDB"
  homepage "https://github.com/lambdadb/lambdadb-migration"
  version "0.1.6"
  license "Apache-2.0"

  on_macos do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/lambdadb-migration_0.1.6_darwin_amd64.tar.gz"
      sha256 "e40ada8169f946c250ad40b82041846756f6cebda20a64e86129940cfc385f85"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/lambdadb-migration_0.1.6_darwin_arm64.tar.gz"
      sha256 "628c9c1d660efb13ec2c6b8e7674b7feec8bdef21c9b82a1df10b09b61aa1645"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/lambdadb-migration_0.1.6_linux_amd64.tar.gz"
      sha256 "d743b0e4645bcfbbe48c2fad0b51bdc37ee4bc96c6c12500cfc78d20b5f8ad04"
    end
    on_arm do
      url "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/lambdadb-migration_0.1.6_linux_arm64.tar.gz"
      sha256 "09c41a36724cccca19b11c2ee3477e313eeb9f1eb31a4d8a98f77673102bab9d"
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

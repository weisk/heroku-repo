require "vendor/heroku/okjson"

# Slug manipulation
class Heroku::Command::Repo < Heroku::Command::BaseWithApp

  # repo:purge-cache
  #
  # Deletes the contents the build cache in the repository
  #
  def purge_cache
    run <<EOF
set -e
mkdir -p tmp/repo_tmp/unpack
cd tmp/repo_tmp
curl -o repo.tgz '#{repo_get_url}'
cd unpack
tar -zxf ../repo.tgz
rm -rf .cache/* .cache/.heroku
tar -zcf ../repack.tgz .
curl -o /dev/null --upload-file ../repack.tgz '#{repo_put_url}'
exit
EOF
  end
  alias_command "repo:purge-cache", "repo:purge_cache"

  # repo:gc
  #
  # Run a git gc --agressive on the applications repository
  #
  def gc
    run <<EOF
set -e
mkdir -p tmp/repo_tmp/unpack
cd tmp/repo_tmp
curl -o repo.tgz '#{repo_get_url}'
cd unpack
tar -zxf ../repo.tgz
git gc --aggressive
tar -zcf ../repack.tgz .
curl -o /dev/null --upload-file ../repack.tgz '#{repo_put_url}'
exit
EOF
  end

  # repo:download
  #
  # Download the repository
  def download
    puts repo_get_url
    system("curl -o #{app}-repo.tgz '#{repo_get_url}'")
  end

  # repo:reset
  #
  # Reset the repo and cache
  def reset
    run <<EOF
set -e
mkdir -p tmp/repo_tmp/unpack
cd tmp/repo_tmp/unpack
git init --bare .
tar -zcf ../repack.tgz .
curl -o /dev/null --upload-file ../repack.tgz '#{repo_put_url}'
exit
EOF
  end

  # repo:rebuild
  #
  # Force a rebuild of the master branch
  def rebuild
    reset
    system "git push #{extract_app_from_git_config || "heroku"} master"
  end

  private

  def release
    @release ||= Heroku::OkJson.decode(heroku.get('/apps/' + app + '/releases/new'))
  end

  def repo_get_url
    release['repo_get_url']
  end

  def repo_put_url
    release['repo_put_url']
  end

  def run(cmds)
    tmpfile = Tempfile.new('heroku-repo')
    begin
      tmpfile.write(cmds)
      tmpfile.close
      real_stdin = $stdin
      $stdin = File.open(tmpfile.path, 'r')
      Heroku::Command::Run.new(["bash"], :app => app).index
      $stdin = real_stdin
    ensure
      tmpfile.close
      tmpfile.unlink
    end
  end
end

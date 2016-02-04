#!/usr/bin/env ruby
# vim: set syntax=ruby :

require_relative 'utils'

# ResourceIn implements the `in` command to download a ref.
class ResourceIn
  include Utils

  # Create a constructor that allows injection of parameters
  # mostly for testing or for defining custom clients and configs.
  #
  # @param client [Octokit::Client] Github client to use for requests
  # @param config [Hash] Configuration hash
  def initialize(client: nil, config: nil)
    @client = client unless client.nil?
    @config = config unless config.nil?
  end

  # Clone the repository into the source path at some PR ref.
  # Shells out to git.
  #
  # @param uri    [String]  The name of the repository.
  # @param pr_num [Integer] The PR number.
  # @param dir    [String]  Directory to clone to
  def self.clone(uri, pr_num, dir)
    status = spawn('git', 'clone', '--depth', '1', uri, dir)
    fail StandardError, "Failed to clone repo: #{uri}" unless status.success?

    Dir.chdir(dir) do
      pr_ref = "refs/pull/#{pr_num}/head:pr"
      status = spawn('git', 'fetch', '--depth', '1', 'origin', pr_ref)
      fail StandardError, "Failed to fetch PR #{pr_num}" unless status.success?

      status = spawn('git', 'checkout', 'pr')
      fail StandardError, 'Failed to checkout PR' unless status.success?
    end
  end

  # Get the metadata for a given commit and coerce it into a nicer format
  #
  # @param client [Octokit::Client] Github client
  # @param repo   [String] Repo name
  # @param sha    [String] Commit hash of the thing to get
  def self.get_commit_metadata(client, repo, sha)
    c = client.commit(repo, sha)
    commit = c.commit

    [
      { name: 'commit', value: c.sha },
      { name: 'author', value: commit.author.name },
      { name: 'author_date', value: commit.author.date },
      { name: 'committer', value: commit.committer.name },
      { name: 'committer_date', value: commit.committer.date },
      { name: 'message', value: commit.message }
    ]
  end

  # Parse the version in the form: pr45:sha into its parts:
  # [45, "sha"]
  #
  # @param version [String] The version to parse.
  # @return        [Array] The two parts of the version string
  def self.parse_version(version)
    parts = version.split(':')
    parts[0] = parts[0].gsub(/pr/, '').to_i
    parts
  end

  # Client returns a github client based on the
  #
  # @return [Octokit::Client] Returns a github client
  def client
    return @client if @client
    token = config['source']['access_token']
    @client = Octokit::Client.new(access_token: token,
                                  auto_paginate: true)
  end

  # out_path is the output path specified by concourse
  #
  # @return [String] The full path to the file to output
  def out_path
    return @out_path if @out_path
    outdir = ARGV.first
    assert outdir, 'Output directory not supplied'
    assert File.directory?(outdir), "Output directory #{outdir} not a directory"
    @out_path = File.join(outdir, File.basename(file_name))
  end

  # Clone PR into the given directory
  #
  # @return [String] The result of the in is as per concourse docs.
  #                  A hash containing version & metadata, the metadata provided
  #                  here is essentially the git commit information.
  def run
    source = config['source']
    version = config['version']
    pr_num, sha = ResourceIn.parse_version(version)

    uri = source['uri']
    repo = get_repo_name(uri)

    meta = ResourceIn.get_commit_metadata(client, repo, version)
    ResourceIn.clone(uri, pr_num, out_path)

    { version: sha, metadata: meta }
  end
end

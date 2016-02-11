#!/usr/bin/env ruby

require 'json'
require 'octokit'

# The error raised when an assertion is not met
class AssertionError < RuntimeError; end

# Utils are misc functions
module Utils
  # Assert that a condition is met
  #
  # @param condition [Boolean] the condition to meet
  # @param message [String] the message associated with the assertion
  # @raise [AssertionError] if the condition was not met
  def assert(condition, message)
    fail AssertionError, message unless condition
  end

  # Get the configuration provided by concourse from standard in
  #
  # @return [Hash] The provided configuration
  def config
    return @config if @config
    config = JSON.load(STDIN)
    assert config, 'Failed to load configs from stdin'
    assert config.respond_to?(:to_hash), 'Loaded config is not a hash'
    @config = config.to_hash
  end

  # Get the repo name from a repo url
  #
  # @param repo_uri [String] The uri to the repo (http(s)/ssh format)
  # @return         [String] The repository name
  def get_repo_name(repo_uri)
    repo_name = nil
    begin
      # http/https?
      repo_url = URI.parse(repo_uri)
      repo_name = repo_url.path[1..repo_url.path.length - 1]
    rescue URI::InvalidURIError
      # Should be an ssh address
      repo_name = repo_uri.split(':')[1]
    end

    repo_name.gsub(/\.git/, '')
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

  # Spawn a process and return its status
  #
  # @param args [Array of String] command line to spawn
  # @returns [Process::Status] the exit status
  def spawn(*args)
    fileno = STDERR.fileno
    _, status = Process.wait2(Process.spawn(*args, out: fileno, err: fileno))
    status
  end
end

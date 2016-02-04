#!/usr/bin/env ruby
require 'uri'
require 'utils'

# ResourceCheck implements the `check` command to locate previously-unseen
# refs in PR's.
class ResourceCheck
  include Utils

  STATUS_NAME        = 'ci-seen'
  STATUS_DESCRIPTION = 'Check to see if ci has seen this commit'

  # Create a constructor that allows injection of parameters
  # mostly for testing or for defining custom clients and configs.
  #
  # @param client [Octokit::Client] Github client to use for requests
  # @param config [Hash] Configuration hash
  def initialize(client: nil, config: nil)
    @config = config unless config.nil?
    @client = client unless client.nil?
  end

  # Filter out any PR that has the check, by performing the check on each PR
  # This removes PRs that have been touched by the check already, and returns
  # the latest commit that doesn't have the status on each PR alongside it's PR.
  #
  # @param client [Octokit::Client] The github client
  # @param repo   [String] Repository name
  # @param prs    [Array] Sawyer::Resource pull request array.
  # @return       [Array] Array of: { pr: Sawyer::Resource, sha: commit }
  def self.filter_touched_prs(client, repo, prs)
    combined = []
    prs.each do |pr|
      commit_hash = untouched_commit_for_pr(client, repo, pr.number)
      combined.push(pr: pr, sha: commit_hash) unless commit_hash.nil?
    end

    combined
  end

  # Get all PRs
  #
  # @param client [Octokit::Client] The github client
  # @param repo   [String] Repository uri
  # @param branch [String] Branch
  # @return       [PullRequest] PullRequest objects from Octokit
  def self.fetch_prs(client, repo, branch: nil)
    prs = client.pull_requests(repo, state: 'open')
    prs.reject! { |pr| pr.base.label != branch } if branch
    prs
  end

  # Get all commits associated with PRs
  #
  # @param client [Octokit::Client] The github client
  # @param repo   [String] Repository name
  # @param pr_num [String] The number of the PR
  # @return       [Array]  Array of Sawyer::Resource commits
  def self.fetch_pr_commits(client, repo, pr_num)
    # The assumption here is that we don't have to sort on anything, we avoid
    # trying to do this because the true source of truth is the git graph
    # but all we'd have access to here is timestamps. Hopefully github knows
    # more about the graph than we do.
    client.pull_request_commits(repo, pr_num)
  end

  # Get the latest commit hash from a PR with a missing the status. Nil if
  # the status is present on the latest commit.
  #
  # @param client [Octokit::Client] The github client
  # @param repo   [String] Repository name
  # @param pr     [String] The pr number to check for the status
  # @return       [String] SHA hash of the commit without the status or nil
  def self.untouched_commit_for_pr(client, repo, pr_num)
    latest_commit = fetch_pr_commits(client, repo, pr_num).last
    return nil if latest_commit.nil? ||
                  commit_has_status?(client,
                                     repo,
                                     latest_commit.commit.tree.sha)

    latest_commit.commit.tree.sha
  end

  # Check if a commit has the status
  #
  # @param client [Octokit::Client] The github client
  # @param repo   [String] Repository name
  # @param sha    [String] The sha of the ref to check
  # @return       [Bool] Whether or not the status was on the commit
  def self.commit_has_status?(client, repo, sha)
    statuses = client.statuses(repo, sha)
    found = statuses.find do |s|
      s.context == STATUS_NAME && s.status == 'success'
    end

    found != nil
  end

  # Set the commit status
  #
  # @param client [Octokit::Client] The client to fetch commits with
  # @param repo   [String] Repository name.
  # @param sha    [String] The sha of the ref to check.
  # @param url    [String] URL to attach to the status.
  def self.set_commit_status(client, repo, sha, url)
    client.create_status(repo, sha, 'success',
                         context: STATUS_NAME,
                         description: STATUS_DESCRIPTION,
                         target_url: url)
  end

  # Client returns a github client based on the
  #
  # @return [Octokit::Client] Returns a github client
  def client
    token = config['source']['access_token']
    @client ||= Octokit::Client.new(access_token: token,
                                    auto_paginate: true)
  end

  # Check for new PR commits
  #
  # @return [Array] The result of the check as a hash as per concourse docs.
  #         This resource only ever outputs one thing because it keeps
  #         it's state separate to concourse (in github commit status)
  #         and so it never needs to return an array of things.
  def run
    source = config['source']
    repo = get_repo_name(source['uri'])

    prs = ResourceCheck.fetch_prs(client, repo, branch: source['branch'])
    pr_commits = ResourceCheck.filter_touched_prs(client, repo, prs)

    return [] if pr_commits.empty?

    next_pr = pr_commits.first
    [{ 'commit' => "pr#{next_pr[:pr].number}:#{next_pr[:sha]}" }]
  end
end

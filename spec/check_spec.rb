require 'spec_helper'
require 'check'
require 'recursive-open-struct'

context ResourceCheck do
  let(:client) { instance_double('Octokit::Client') }
  let(:repo) { 'https://github.com/hpcloud/fun' }
  let(:sha1) { 'abdcef' }
  let(:sha2) { 'fecdba' }
  let(:commit1) { { sha: sha1 } }
  let(:commit2) { { sha: sha2 } }
  let(:commits) { mk_structs([commit1, commit2]) }

  it 'should run fetch the PR details for the next untouched PR' do
    allow(client).to receive(:pull_requests)
      .and_return(mk_structs([
        { number: 57 },
        { number: 58 }
      ]))
    allow(client).to receive(:pull_request_commits).and_return(commits)
    allow(client).to receive(:statuses).and_return(mk_structs([
      { context: ResourceCheck::STATUS_NAME, status: 'success' }
    ]), mk_structs([
      { context: 'wrong check', status: 'failure' }
    ]))

    expect(ResourceCheck).to receive(:set_commit_status)
      .with(client, 'hpcloud/fun', sha2)

    r = ResourceCheck.new(
      client: client, config: { 'source' => { 'uri' => repo } }
    )

    latest_pr = r.run
    expect(latest_pr.length).to eq(1)
    expect(latest_pr[0]['commit']).to eq("pr58:#{sha2}")
  end

  it 'should filter touched prs' do
    allow(client).to receive(:pull_request_commits).and_return(commits)

    allow(client).to receive(:statuses).and_return(mk_structs([
      { context: ResourceCheck::STATUS_NAME, status: 'success' }
    ]), mk_structs([
      { context: 'wrong check', status: 'failure' }
    ]))

    prs = mk_structs([
      { number: 57 },
      { number: 58 }
    ])

    prs = ResourceCheck.filter_touched_prs(client, repo, prs)
    expect(prs.length).to eq(1)
    expect(prs[0][:pr].number).to eq(58)
  end

  describe 'fetch_prs' do
    it 'should fetch prs' do
      allow(client).to receive(:pull_requests).and_return(mk_structs([
        { base: { label: 'master' } },
        { base: { label: 'master' } }
      ]))

      prs = ResourceCheck.fetch_prs(client, repo)
      expect(prs.length).to eq(2)
    end

    it 'should filter fetched prs' do
      allow(client).to receive(:pull_requests).and_return(mk_structs([
        { base: { label: 'master' } },
        { base: { label: 'develop' } }
      ]))

      prs = ResourceCheck.fetch_prs(client, repo, branch: 'develop')
      expect(prs.length).to eq(1)
      expect(prs[0].base.label).to eq('develop')
    end
  end

  it 'should fetch pr commits' do
    allow(client).to receive(:pull_request_commits).and_return(mk_structs([
      commit1, commit2
    ]))

    commits = ResourceCheck.fetch_pr_commits(client, repo, 55)
    expect(commits.length).to eq(2)
  end

  describe 'commit_has_status?' do
    it 'should check if a commit has the status' do
      allow(client).to receive(:statuses).and_return(mk_structs([
        { context: 'not the right status', status: 'failure' },
        { context: ResourceCheck::STATUS_NAME, status: 'success' }
      ]))

      status = ResourceCheck.commit_has_status?(client, repo, 'sha')
      expect(status).to eq(true)
    end

    it 'should check if a commit does not have the status' do
      allow(client).to receive(:statuses).and_return(mk_structs([
        { context: 'not the right status', status: 'failure' },
        { context: ResourceCheck::STATUS_NAME, status: 'failure' }
      ]))

      status = ResourceCheck.commit_has_status?(client, repo, 'sha')
      expect(status).to eq(false)
    end
  end

  describe 'untouched_commit_for_pr' do
    let(:pr_num) { 55 }

    it 'should return nil if the pr is touched' do
      statuses = mk_structs([
        { context: ResourceCheck::STATUS_NAME, status: 'success' }
      ])

      allow(client).to receive(:pull_request_commits).and_return(commits)
      allow(client).to receive(:statuses).and_return(statuses)

      commit = ResourceCheck.untouched_commit_for_pr(client, repo, pr_num)
      expect(commit).to be_nil
    end

    it 'should return the sha if the pr is untouched' do
      allow(client).to receive(:pull_request_commits).and_return(commits)
      allow(client).to receive(:statuses).and_return(mk_structs([
        { context: 'not the right status', status: 'failure' }
      ]))

      commit = ResourceCheck.untouched_commit_for_pr(client, repo, pr_num)
      expect(commit).to eq(sha2)
    end

    it 'should return false if there are no commits' do
      allow(client).to receive(:pull_request_commits).and_return([])

      status = ResourceCheck.untouched_commit_for_pr(client, repo, pr_num)
      expect(status).to be_nil
    end
  end

  describe 'set_commit_status' do
    it 'should set the commit status for a commit' do
      allow(client).to receive(:create_status)
        .with(repo, 'sha', 'success',
              context: ResourceCheck::STATUS_NAME,
              description: ResourceCheck::STATUS_DESCRIPTION)
        .and_return(nil)

      status = ResourceCheck.set_commit_status(client, repo, 'sha')
      expect(status).to be_nil
    end
  end
end

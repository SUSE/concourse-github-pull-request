require 'spec_helper'
require 'ostruct'
require 'in'

context ResourceIn do
  let(:client) { instance_double('Octokit::Client') }
  let(:uri) { 'git@github.com:hpcloud/fun' }
  let(:repo) { 'hpcloud/fun' }
  let(:branch) { 'branch' }
  let(:pr_num) { 5 }
  let(:sha) { 'abcdef' }
  let(:version) { "pr#{pr_num}:#{sha}" }
  let(:config) do
    {
      'source' => { 'uri' => uri, 'branch' => branch },
      'version' => { 'commit' => version }
    }
  end
  let(:metatime) { Time.new(2001, 01, 01, 1, 1, 1) }
  let(:metadata) do
    mk_structs(
      sha: sha,
      commit: {
        author: {
          name: 'author name',
          email: 'author@github.com',
          date: metatime
        },
        committer: {
          name: 'committer name',
          email: 'committer@github.com',
          date: metatime
        },
        message: 'commit message'
      }
    )
  end
  let(:expect_meta) do
    [
      { name: 'commit', value: sha },
      { name: 'author', value: 'author name' },
      { name: 'author_date', value: metatime },
      { name: 'committer', value: 'committer name' },
      { name: 'committer_date', value: metatime },
      { name: 'message', value: 'commit message' }
    ]
  end

  before do
    expect(STDIN).to receive(:read).exactly(0).times
    expect(STDERR).not_to receive(:puts)
  end

  it 'should return the version and the metadata when run' do
    expect(client).to receive(:commit).and_return(metadata)

    resource = ResourceIn.new(client: client, config: config)
    expect(resource).to receive(:out_path).and_return('out')
    expect(ResourceIn).to receive(:clone)
      .with(uri, pr_num, sha, 'out', pkey: nil)
      .and_return(nil)

    output = resource.run
    expect(output[:metadata]).to eq(expect_meta)
    expect(output[:version]).to eq(config['version'])
  end

  it 'should get commit metadata' do
    expect(client).to receive(:commit).and_return(metadata)
    meta = ResourceIn.get_commit_metadata(client, repo, sha)
    expect(meta).to eq(expect_meta)
  end

  it 'should parse concatenated version strings' do
    num, sha = ResourceIn.parse_version(version)
    expect(num).to eq(pr_num)
    expect(sha).to eq(sha)
  end

  it 'should clone a repository' do
    expect(FileUtils).to receive(:mkdir_p).with('dir')
    expect(Dir).to receive(:chdir) do |_dir, &block|
      block.call
    end

    ref = "refs/pull/#{pr_num}/head:pr"

    expect(Utils).to receive(:run_process)
      .with('git', 'init')
      .and_return(OpenStruct.new(success?: true))
      .ordered
    expect(Utils).to receive(:run_process)
      .with('git', 'remote', 'add', 'origin', uri)
      .and_return(OpenStruct.new(success?: true))
      .ordered
    expect(Utils).to receive(:run_process)
      .with('git', 'fetch', '--depth', '1', 'origin', ref)
      .and_return(OpenStruct.new(success?: true))
      .ordered
    expect(Utils).to receive(:run_process)
      .with('git', 'checkout', sha)
      .and_return(OpenStruct.new(success?: true))
      .ordered
    expect(Utils).to receive(:run_process)
      .with(*'git submodule update --init --recursive --depth 1'.split)
      .and_return(OpenStruct.new(success?: true))
      .ordered

    expect(ResourceIn).to receive(:write_ssh_config)
    expect(ResourceIn).to receive(:write_private_key).with('pkey')

    ResourceIn.clone(uri, pr_num, sha, 'dir', pkey: 'pkey')
  end

  it 'should write the ssh directory' do
    expect(Dir).to receive(:exist?)
      .with(ResourceIn::SSH_DIR)
      .and_return(false)

    expect(FileUtils).to receive(:mkdir_p).with(ResourceIn::SSH_DIR)
    expect(FileUtils).to receive(:chmod).with(0700, ResourceIn::SSH_DIR)

    ResourceIn.create_ssh_dir
  end

  it 'should write an ssh_config' do
    writer = double('File')
    expect(writer).to receive(:write)
      .with(ResourceIn::SSH_CONFIGURATION)
    expect(File).to receive(:exist?).and_return(false)

    expect(File).to receive(:open)
      .with(ResourceIn::SSH_CONFIG_FILE, 'w') do |&block|
        block.call(writer)
      end

    expect(FileUtils).to receive(:chmod).with(0600, ResourceIn::SSH_CONFIG_FILE)

    ResourceIn.write_ssh_config
  end

  it 'should write a private key file' do
    writer = double('File')
    expect(writer).to receive(:write).with('pkey')

    expect(File).to receive(:open)
      .with(ResourceIn::SSH_KEY_FILE, 'w') do |&block|
        block.call(writer)
      end

    expect(FileUtils).to receive(:chmod).with(0600, ResourceIn::SSH_KEY_FILE)

    ResourceIn.write_private_key('pkey')
  end

  describe '#out_path' do
    it 'should return cached output path' do
      expected = {}
      subject.instance_variable_set(:@out_path, expected)
      expect(subject.out_path).to be(expected)
    end

    it 'should abort if the output directory is not given' do
      expect(ARGV).to receive(:first).and_return(nil)
      expect do
        subject.out_path
      end.to raise_error(AssertionError, /output directory.*not supplied/i)
    end

    it 'should return the output directory if valid' do
      out_dir = 'out'

      expect(ARGV).to receive(:first).and_return(out_dir)
      expect(subject.out_path).to eq(out_dir)
    end
  end
end

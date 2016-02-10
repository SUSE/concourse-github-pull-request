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
      'version' => version
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
      .with(uri, pr_num, 'out')
      .and_return(nil)

    output = resource.run
    puts output
    expect(output[:metadata]).to eq(expect_meta)
    expect(output[:version]).to eq(sha)
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

    it 'should abort if the output directory is missing' do
      expect(ARGV).to receive(:first).and_return('out')
      expect do
        subject.out_path
      end.to raise_error(AssertionError, /output directory.*not a directory/i)
    end

    it 'should return the output directory if valid' do
      out_dir = 'out'

      expect(File).to receive(:directory?).with(out_dir).and_return(true)
      expect(ARGV).to receive(:first).and_return(out_dir)
      expect(subject).to receive(:file_name).and_return('file-name')
      expect(subject.out_path).to eq(File.join(out_dir, 'file-name'))
    end
  end
end

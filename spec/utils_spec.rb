require 'json'
require 'utils'

context Utils do
  subject do
    # A class wrapper so the mixin can be included
    class MixedInTestClass
      include Utils
    end
    MixedInTestClass.new
  end

  describe 'assert' do
    before do
      expect(STDERR).not_to receive(:puts)
    end

    it 'should do nothing on success' do
      expect do
        subject.assert true, 'Unused message'
      end.not_to raise_error
    end

    it 'should exit on failure' do
      message = 'This is a test message'
      expect do
        subject.assert false, message
      end.to raise_error(AssertionError, message)
    end
  end

  describe 'config' do
    let(:sample) { ({ foo: 1, bar: { nested: true } }) }

    before do
      allow(STDERR).to receive(:puts)
    end

    it 'should load configs from stdin' do
      expected = sample.to_json
      expect(STDIN).to receive(:read).and_return(expected)
      expect(subject.config.to_json).to eq(expected)
    end

    it 'should reject non-hashes' do
      expected = (42).to_json
      expect(STDIN).to receive(:read).and_return(expected)
      expect { subject.config }.to raise_error(AssertionError, /not a hash/i)
    end

    it 'should reject no input' do
      expect(STDIN).to receive(:read)
      expect { subject.config }.to raise_error(AssertionError, /stdin/i)
    end
  end

  describe 'repo_name' do
    it 'should take http/https urls' do
      uri = 'https://github.com/hpcloud/fun.git'
      repo_name = subject.get_repo_name(uri)
      expect(repo_name).to eq('hpcloud/fun')
    end

    it 'should take git urls' do
      uri = 'git@github.com:hpcloud/fun.git'
      repo_name = subject.get_repo_name(uri)
      expect(repo_name).to eq('hpcloud/fun')
    end
  end
end

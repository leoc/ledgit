describe Ledgit::Handler do
  describe '#transaction_exists?' do
    let(:temp_file) do
      file = Tempfile.new('ledger_test_file')
      file.puts(<<LEDGER_CONTENTS)
2017/10/02 * Payee Name
  ; transaction_id: ABC
  Expensens:Some:Account  15.00 EUR
  Assets:Giro  -15.00 EUR

2017/10/03 * Payee Name
  ; transaction_id: DEF
  Expensens:Some:Account  15.00 EUR
  Assets:Giro  -15.00 EUR
LEDGER_CONTENTS
      file.flush
      file
    end
    let(:account) do
      Ledgit::Account.new(
        'name' => 'Assets:Giro',
        'ledger_file' => temp_file.path,
        'handler' => 'dkb/giro',
        'credentials' => {}
      )
    end
    let(:file) { Ledgit::LedgerFile.new(temp_file.path) }
    let(:handler) { Ledgit::Handler.new(account) }

    it 'returns true if id can be found in file' do
      test_transaction = {
        id: 'ABC',
        booking_date: Date.new(2017, 10, 2),
        tags: {
          some_tag: 'some value',
          some_other_tag: 'some other value'
        }
      }
      expect(handler.transaction_exists?(test_transaction)).to eq(true)
    end

    it 'returns false if given parameters do not exist in file' do
      test_transaction = {
        id: 'FOO',
        booking_date: Date.new(2017, 10, 3),
        tags: {
          some_tag: 'some value'
        }
      }
      expect(handler.transaction_exists?(test_transaction)).to eq(false)
    end
  end

    describe '#filter_transaction?' do
    let(:temp_file) { Tempfile.new('ledger_test_file') }
    let(:account) do
      Ledgit::Account.new(
        'name' => 'Assets:Giro',
        'ledger_file' => temp_file.path,
        'handler' => 'dkb/giro',
        'filters' => {},
        'credentials' => {}
      )
    end
    let(:file) { Ledgit::LedgerFile.new(temp_file.path) }
    let(:handler) { Ledgit::Handler.new(account) }

    it 'is truthy matching specific tag' do
      filters = [{ 'some_tag' => 'some matching value' }]
      transaction = {
        tags: {
          some_tag: 'some matching value'
        }
      }
      expect(handler.filter_transaction?(transaction, filters)).to be_truthy
    end
    it 'is falsy not matching specific tag' do
      filters = [{ 'some_tag' => 'some matching value' }]
      transaction1 = { tags: { some_tag: 'some not matching value' } }
      expect(handler.filter_transaction?(transaction1, filters)).to be_falsy
      transaction2 = {}
      expect(handler.filter_transaction?(transaction2, filters)).to be_falsy
    end
    it 'is truthy matching multiple tag' do
      filters = [{ 'some_tag' => 'some matching value',
                   'some_other_tag' => 'some other matching value' }]
      transaction1 = { tags: { some_tag: 'some matching value',
                               some_other_tag: 'some other matching value' } }
      expect(handler.filter_transaction?(transaction1, filters)).to be_truthy
    end
    it 'is falsy not matching multiple tag' do
      filters = [{ 'some_tag' => 'some matching value',
                   'some_other_tag' => 'some other matching value' }]
      transaction1 = { tags: { some_tag: 'some not matching value',
                               some_other_tag: 'some other matching value' } }
      expect(handler.filter_transaction?(transaction1, filters)).to be_falsy
    end
    it 'is truthy matching one of multiple filters' do
      filters = [{ 'some_tag' => 'some matching value' },
                 { 'some_other_tag' => 'some other matching value' }]
      transaction1 = { tags: { some_tag: 'some not matching value',
                               some_other_tag: 'some other matching value' } }
      expect(handler.filter_transaction?(transaction1, filters)).to be_truthy
    end
  end
end

describe Ledgit::Extension::ExtractPattern do
  describe '#apply' do
    let(:transaction1) do
      {
        booking_date: Date.new(2017, 6, 1),
        tags: {
          description: 'ELV123456789 29.05 17.21 ME2'
        }
      }
    end

    describe 'matching no tag' do
      let(:config) do
        [
          {
            'pattern' => 'Something not matching ...',
            'overrides' => {
              'booking_date' => '${match:day}/${match:month}/${booking_date_year}',
              'tags' => {
                'timestamp' => '${booking_date_year}-${match:month}-${match:day}T${match:hour}:${match:minute}:00Z'
              }
            }
          }
        ]
      end
      let(:extract_pattern) { Ledgit::Extension::ExtractPattern.new(config) }

      it 'keeps transaction1' do
        expect(extract_pattern.apply(transaction1)).to eq(transaction1)
      end
    end

    describe 'matching all tags' do
      let(:config) do
        [
          {
            'pattern' => 'ELV\\d+ (?<day>\\d{2})\\.(?<month>\\d{2}) (?<hour>\\d{2})\\.(?<minute>\\d{2}) ME2',
            'overrides' => {
              'booking_date' => '${match:day}/${match:month}/${booking_date_year}',
              'tags' => {
                'timestamp' => '${booking_date_year}-${match:month}-${match:day}T${match:hour}:${match:minute}:00Z'
              }
            }
          }
        ]
      end
      let(:extract_pattern) { Ledgit::Extension::ExtractPattern.new(config) }

      it 'transforms transaction1' do
        altered_transaction = {
          booking_date: Date.new(2017, 5, 29),
          tags: {
            description: 'ELV123456789 29.05 17.21 ME2',
            timestamp: '2017-05-29T17:21:00Z'
          }
        }
        expect(extract_pattern.apply(transaction1)).to eq(altered_transaction)
      end
    end
    describe 'ignoring `description` tag' do
      let(:config) do
        [
          {
            'pattern' => 'ELV\\d+ (?<day>\\d{2})\\.(?<month>\\d{2}) (?<hour>\\d{2})\\.(?<minute>\\d{2}) ME2',
            'ignore_tags' => ['description'],
            'overrides' => {
              'booking_date' => '${match:day}/${match:month}/${booking_date_year}',
              'tags' => {
                'timestamp' => '${booking_date_year}-${match:month}-${match:day}T${match:hour}:${match:minute}:00Z'
              }
            }
          }
        ]
      end
      let(:extract_pattern) { Ledgit::Extension::ExtractPattern.new(config) }

      it 'keeps transaction1' do
        expect(extract_pattern.apply(transaction1)).to eq(transaction1)
      end
    end
  end
end

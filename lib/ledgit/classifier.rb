require 'fileutils'
require 'jaccard'
require 'andand'

# Naive implementation for classifying accounts via Jaccard string
# distance and frequency of usage.
class Ledgit
  class Classifier
    attr_reader(:filename)

    IGNORE_TAGS = [
      'transaction_id',
      'account_number',
      'bank_code',
      'booking_text',
      'location',
      'payment_status',
      'payment_type',
      'timestamp',
      'transaction_account_number',
      'transaction_bank_code',
      'transaction_booking_text',
      'transaction_type',
      'type'
    ]

    def initialize(filename)
      @filename = File.expand_path(filename)
      @accounts = clean_accounts(load_accounts(load_csv))
    end

    def classify(tags: {}, transfer: :out)
      accs = {}
      tags.each_pair do |k, v|
        (@accounts[transfer].andand[k.to_s] || {}).each_pair do |value, accounts|
          accounts.each_pair do |name, count|
            comparable_value = clean_tag_value(v)
            distance = 1 - Jaccard.distance(comparable_value.scan(/..?/), value.scan(/..?/))

            accs[name] ||= 0
            accs[name] += distance
          end
        end
      end
      accs.to_a.sort { |a, b| a[1] <=> b[1] }.last.andand[0]
    end

    private

    def load_csv
      `ledger -f "#{@filename}" csv`.gsub("\\\"", "\"\"")
    end

    def load_accounts(csv)
      accounts = {}
      CSV.parse(csv) do |row|
        account = row[3]
        amount = row[5]
        tags = extract_tags(row[7])
        type = amount[0] == '-' ? :in : :out
        tags.each_pair do |tag, value|
          next if IGNORE_TAGS.include?(tag)
          next if account =~ /^Assets:Funds/ || account =~ /^Liabilities:Funds/
          clean_value = clean_tag_value(value)
          next if clean_value.andand.length <= 0
          accounts[type] ||= {}
          accounts[type][tag] ||= {}
          accounts[type][tag][clean_value] ||= {}
          accounts[type][tag][clean_value][account] ||= 0
          accounts[type][tag][clean_value][account] += 1
        end
      end
      accounts
    end

    def clean_tag_value(str)
      @cleanable_values ||= {}
      @cleanable_values[str] =
        str
        .downcase
        .gsub(/[^A-Za-z]/, ' ')
        .split(' ')
        .uniq
        .reject { |v| v.length < 3 }
        .join(' ')
    end

    def clean_accounts(accounts)
      accounts.map do |k1,v1|
        sub1 = v1.map do |k2,v2|
          sub2 = v2.map do |k3, v3|
            sub3 = v3.map do |k4, v4|
              next if v4 <= 1
              [k4, v4]
            end.compact.to_h
            next if sub3.empty?
            [k3, sub3]
          end.compact.to_h
          next if sub2.empty?
          [k2, sub2]
        end.compact.to_h
        next if sub1.empty?
        [k1, sub1]
      end.compact.to_h
    end

    def extract_tags(str)
      tags_hash = {}
      str.split("\\n").map do |tag|
        k,v = tag.split(/:\s+/, 2)
        next if k.nil? || v.nil?
        k = k.strip
        v = v.strip
        tags_hash[k] = v
      end
      tags_hash
    end
  end
end

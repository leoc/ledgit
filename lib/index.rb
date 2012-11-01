class Ledgit
  class Index < Hash

    def load accounts
      accounts.each do |account|
        if account.load_for_index?
          transaction = nil
          if File.exists?(account.ledger_file)
            File.open(account.ledger_file, 'r').each_line do |line|
              # read each transaction
              if line =~ /^[ ]+([\w: ]+?)  ([\d.]+)EUR$/
                unless $1 == account[:name]
                  transaction[:add_accounts] ||= {}
                  transaction[:add_accounts][$1] ||= 0
                  transaction[:add_accounts][$1] += 1
                end
              elsif line =~ /^[ ]+([\w: ]+?)$/
                unless $1 == account[:name]
                  transaction[:sub_accounts] ||= {}
                  transaction[:sub_accounts][$1] ||= 0
                  transaction[:sub_accounts][$1] += 1
                end
              elsif line =~ /^[ ]+; transaction_partner: (.*)$/
                transaction[:partner] = $1
              elsif line =~ /^[ ]+; transaction_account_number: (.*)$/
                transaction[:account_number] = $1
              elsif line =~ /^[ ]+; transaction_bank_code: (.*)$/
                transaction[:bank_code] = $1
              elsif line =~ /^\d+\/\d+\/\d+(=\d+\/\d+\/\d+)?( . | )(.*)$/
                self.add transaction if transaction
                transaction = {}
                transaction[:name] = $3
              end
            end
          end
        end
      end
    end

    def add transaction
      entry = (self["#{transaction[:partner]}-#{transaction[:account_number]}-#{transaction[:bank_code]}"] ||= {})

      entry[:names] ||= {}
      entry[:names][transaction[:name]] =
        (entry[:names][transaction[:name]] or 0) + 1

      (transaction[:add_accounts] or {}).each_pair do |account, count|
        entry[:add_accounts] ||= {}
        entry[:add_accounts][account] =
          (entry[:add_accounts][account] or 0) + count
      end

      (transaction[:sub_accounts] or {}).each_pair do |account, count|
        entry[:sub_accounts] ||= {}
        entry[:sub_accounts][account] =
          (entry[:sub_accounts][account] or 0) + count
      end
    end

    def get_partner_name partner, account_number, bank_code
      entry = self["#{partner}-#{account_number}-#{bank_code}"]
      current_name = nil
      if entry
        highest = 0
        (entry[:names] or {}).each_pair do |name, count|
          current_name = name if count > highest
        end
      end
      current_name
    end

    def get_subtraction_account partner, account_number, bank_code
      entry = self["#{partner}-#{account_number}-#{bank_code}"]
      current_account = nil
      if entry
        highest = 0
        (entry[:sub_accounts] or {}).each_pair do |account, count|
          current_account = account if count > highest
        end
      end
      current_account
    end

    def get_addition_account partner, account_number, bank_code
      entry = self["#{partner}-#{account_number}-#{bank_code}"]
      current_account = nil
      if entry
        highest = 0
        (entry[:add_accounts] or {}).each_pair do |account, count|
          current_account = account if count > highest
        end
      end
      current_account
    end
  end
end

class Ledgit
  class Extension
    class ExtractPattern
      attr_reader(:config)

      def initialize(config)
        @config = config
      end

      def apply(transaction)
        matches = transaction[:tags].flat_map do |tag, value|
          config.map do |element|
            next if (element["ignore_tags"] || []).include?(tag.to_s)
            next nil unless (match = value.match(/#{element["pattern"]}/))
            [
              gather_variables(transaction, match),
              element['overrides']
            ]
          end
        end.compact

        matches.each do |vars, overrides|
          transaction = override_values(transaction, overrides, vars)
        end

        transaction
      end

      def gather_variables(transaction, match)
        vars = match.names.map { |name| ["match:#{name}", match[name]] }.to_h
        vars['booking_date_year'] = transaction[:booking_date].year
        vars['booking_date_month'] = transaction[:booking_date].month
        vars['booking_date_day'] = transaction[:booking_date].day
        vars
      end

      def replace_variables(override, vars)
        str = override.clone
        (vars || {}).each_pair do |name, value|
          str.gsub!("${#{name}}", value.to_s)
        end
        str
      end

      def override_values(transaction, overrides, vars)
        (overrides || {}).each_pair do |key, override|
          transaction[key.to_sym] =
            case key.to_sym
            when :booking_date, :payment_date then Date.parse(replace_variables(override, vars))
            when :tags then override_values(transaction[:tags], override, vars)
            else replace_variables(override, vars)
            end
        end
        transaction
      end
    end
  end
end

Ledgit.extensions['extract_pattern'] = Ledgit::Extension::ExtractPattern

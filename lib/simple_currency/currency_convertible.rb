require 'open-uri'
require 'timeout'
require 'crack/xml'

module CurrencyConvertible

  def method_missing(method, *args, &block)
    return _from(method.to_s) if method.to_s.length == 3 # Presumably a currency ("eur", "gbp"...)

    # Now capture methods like to_eur, to_gbp, to_usd... 
    if @original && !(method.to_s =~ /^to_(utc|int|str|ary)/) && method.to_s =~/^to_/ && method.to_s.length == 6
      return _to(method.to_s.gsub('to_',''))
    end

    super(method,*args,&block)
  end

  # Historical exchange lookup
  def at(exchange = nil)
    begin
       
      @exchange_date = exchange.send(:to_date)
    rescue
      raise "Must use 'at' with a time or date object"
    end
    self
  end

  private
   
    # Called from first currency metamethod to set the original currency.
    # 
    # 30.eur # => Calls _from and sets @original to 'eur'
    #
    def _from(currency)
      @exchange_date = Time.now.send(:to_date)
      @original = currency
      self
    end

    # Called from last currency metamethod to set the target currency.
    # 
    #   30.eur.to_usd 
    #   # => Calls _to and returns the final value, say 38.08
    #
    def _to(target)
      raise unless @original # Must be called after a _from have set the @original currency

      return 0.0 if self == 0 # Obviously

      original = @original

      amount = self

      # Check if there's a cached exchange rate for today
      return cached_amount(original, target, amount) if cached_rate(original, target)

      # If not, perform calls to APIs, deal with caches...
      result = exchange(original, target, amount.abs)

      # Cache methods
      cache_currency_methods(original, target)

      result
    end

    # Main method (called by _to) which calls Xavier or Xurrency strategies
    # and returns a nice result.
    #
    def exchange(original, target, amount)
      negative = (self < 0)

      result = @exchange_date ? call_xavier_api(original, target, amount) : call_xurrency_api(original, target, amount)

      # Round result to 2 decimals
      result = sprintf("%.2f", result).to_f

      return -(result) if negative
      result
    end

    ## 
    # API call strategies
    ##
   
    # Calls Xurrency API to perform the exchange without a specific date (assuming today)
    #
    def call_xurrency_api(original, target, amount)

      if amount > 999_999_999 # Xurrency API does not support numbers bigger than this
        amount = 1
        multiplier = self.abs # Save a multiplier to apply it to the result later
      end

      api_url = "http://xurrency.com/api/#{[original, target, amount].join('/')}"
      uri = URI.parse(api_url)


      retries = 10
      json_response = nil
      begin
        Timeout::timeout(1){
          json_response = uri.open.read || nil # Returns the raw response
        }
      rescue Timeout::Error
        retries -= 1
        retries > 0 ? sleep(0.42) && retry : raise
      end

      return nil unless json_response && parsed_response = Crack::JSON.parse(json_response)
      if parsed_response['status'] != 'ok'
        raise CurrencyNotFoundException if parsed_response['message'] =~ /currencies/
        raise parsed_response['message']
      end

      result = parsed_response['result']['value'].to_f
      cache_rate(original, target, (result / amount))
      result * (multiplier || 1)
    end

    # Calls Xavier API to perform the exchange with a specific date.
    # This method is called when using :at method, like this:
    #
    #   30.eur.at(1.year.ago).to_usd
    #
    def call_xavier_api(original, target, amount)

      # Check if there is any cached XML for the specified date
      if defined?(Rails)
        parsed_response = Rails.cache.read("xaviermedia_#{stringified_exchange_date}")
      end

      unless parsed_response # Unless there is a cached XML response, ask for it
        date = @exchange_date
        args = [date.year, date.month.to_s.rjust(2, '0'), date.day.to_s.rjust(2,'0')]
        api_url = "http://api.finance.xaviermedia.com/api/#{args.join('/')}.xml"

        uri = URI.parse(api_url)

        retries = 10
        not_found_retries=10
        xml_response = nil
        begin
          Timeout::timeout(1){
            # Returns the raw response or
            # raises OpenURI::HTTPError when no data available
            xml_response = uri.open.read || nil
          }
        rescue Timeout::Error
          retries -= 1
          retries > 0 ? sleep(0.42) && retry : raise
        rescue OpenURI::HTTPError # Try to fetch one day and 2 days earlier
          not_found_retries -= 1
          if not_found_retries >= 0
            date = (Time.parse(date.to_s) - 86400).send(:to_date)
            args = [date.year, date.month.to_s.rjust(2, '0'), date.day.to_s.rjust(2,'0')]
            api_url = "http://api.finance.xaviermedia.com/api/#{args.join('/')}.xml"
            uri = URI.parse(api_url)
            retry
          else
            raise "404 Not Found"
          end
        end

        return nil unless xml_response && parsed_response = Crack::XML.parse(xml_response)
        parsed_response = parsed_response["xavierresponse"]["exchange_rates"]["fx"]

        # Cache successful XML response for later reuse
        if defined?(Rails)
          Rails.cache.write("xaviermedia_#{stringified_exchange_date}", parsed_response)
        end
      end

      # Calculate the exchange rate from the XML
      if parsed_response.first['basecurrency'].downcase == original
        rate = parse_rate(parsed_response, target)
      elsif parsed_response.first['basecurrency'].downcase == target
        rate = 1 / parse_rate(parsed_response, original)
      else
        original_rate = parse_rate(parsed_response, original)
        target_rate = parse_rate(parsed_response, target)
        rate = target_rate / original_rate
      end

      cache_rate(original, target, rate)
      amount * rate
    end

    def parse_rate(parsed_response, currency)
      rate = parsed_response.select{|element| element["currency_code"].downcase == currency}
      raise CurrencyNotFoundException, "#{currency} is not a valid currency" unless rate && rate.is_a?(Array) && rate.first
      raise NoRatesFoundException, "no exchange rate found for #{currency}" unless rate.first['rate'] && rate.first['rate'].to_f > 0
      rate.first['rate'].to_f
    end

    # Caches currency methods to avoid method missing abuse.
    #
    def cache_currency_methods(original, target)
      # Cache the _from method for faster reuse
      self.class.send(:define_method, original.to_sym) do
          _from(original)
      end unless self.respond_to?(original.to_sym)

      # Cache the _to method for faster reuse
      self.class.send(:define_method, :"to_#{target}") do
          _to(target)
      end unless self.respond_to?(:"to_#{target}")
    end

    ##
    # Cache helper methods (only useful in a Rails app)
    ##

    # Returns a suitable string-like date (like "25-8-2010"),
    # aware of possible @exchange_date set by :at method
    #
    def stringified_exchange_date
      value = (@exchange_date || Time.now.send(:to_date))
      [value.day, value.month, value.year].join('-')
    end

    # Writes rate to the cache.
    #
    def cache_rate(original, target, rate)
      Rails.cache.write("#{original}_#{target}_#{stringified_exchange_date}", rate) if defined?(Rails)
    end

    # Tries to either get rate or calculate the inverse rate from cache.
    #
    # First looks for an "usd_eur_25-8-2010" entry in the cache,
    # and if it does not find it, it looks for "eur_usd_25-8-2010" and
    # inverts it.
    #
    def cached_rate(original, target)
      if defined?(Rails)
        unless rate = Rails.cache.read("#{original}_#{target}_#{stringified_exchange_date}")
          rate = (1.0 / Rails.cache.read("#{target}_#{original}_#{stringified_exchange_date}")) rescue nil
        end
        rate
      end
    end

    # Checks if there's a cached rate and calculates the result
    # from the amount (or returns nil).
    #
    def cached_amount(original, target, amount)
      if rate = cached_rate(original, target)
        result = (amount * rate).to_f
        return result = (result * 100).round.to_f / 100
      end
      nil
    end

end

  ##
  # Custom Exceptions
  ##
   
  class CurrencyNotFoundException < StandardError
  end

  class NoRatesFoundException < StandardError
  end



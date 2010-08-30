require 'open-uri'
require 'timeout'
require 'json'

module CurrencyConvertible

  def method_missing(method, *args, &block)
    return _from(method.to_s) if method.to_s.length == 3 # Presumably a currency ("eur", "gbp"...)

    # Now capture methods like to_eur, to_gbp, to_usd... 
    if @original && !(method.to_s =~ /^to_(utc|int|str|ary)/) && method.to_s =~/^to_/ && method.to_s.length == 6
      return _to(method.to_s.gsub('to_',''))
    end

    super(method,*args,&block)
  end

  private
    
    def _from(currency)
      @original = currency
      self
    end

    def _to(target)
      raise unless @original # Must be called after a _from have set the @original currency

      original = @original
      amount = self

      # Check if there's a cached exchange rate for today
      if defined?(Rails) && cached_amount = check_cache(original, target, amount)
        return cached_amount
      end

      # If not, perform a call to the api
      json_response = call_api(original, target, amount)
      return nil unless json_response
      result = sprintf("%.2f", JSON.parse(json_response)["result"]["value"]).to_f

      # Cache exchange rate for today only
      Rails.cache.write("#{original}_#{target}_#{Time.now.to_a[3..5].join('-')}", calculate_rate(amount,result)) if defined?(Rails)

      # Cache the _from method for faster reuse
      self.class.send(:define_method, original.to_sym) do
          _from(original)
      end unless self.respond_to?(original.to_sym)

      # Cache the _to method for faster reuse
      self.class.send(:define_method, :"to_#{target}") do
          _to(target)
      end unless self.respond_to?(:"to_#{target}")

      result
    end

    def check_cache(original, target, amount)
      if rate = ::Rails.cache.read("#{original}_#{target}_#{Time.now.to_a[3..5].join('-')}")
        result = (amount * rate).to_f
        return result = (result * 100).round.to_f / 100
      end
      nil
    end

    def call_api(original, target, amount)
      api_url = "http://xurrency.com/api/#{[original, target, amount].join('/')}"
      uri = URI.parse(api_url)

      retries = 10
      begin
        Timeout::timeout(1){
          uri.open.read || nil # Returns the raw response
        }
      rescue Timeout::Error
        retries -= 1
        retries > 0 ? sleep(0.42) && retry : raise
      end
    end

    def calculate_rate(amount,result)
      (result / amount).to_f
    end

end

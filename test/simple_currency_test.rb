require 'test_helper'

describe "SimpleCurrency" do

  it "enhances instances of Numeric with currency methods" do
    30.eur.must_be_kind_of CurrencyConvertible::Proxy
    30.usd.must_be_kind_of CurrencyConvertible::Proxy
    30.gbp.must_be_kind_of CurrencyConvertible::Proxy
  end

  it "handles zero values (by returning them straight away)" do
    0.usd.to_eur.must_equal 0.0 
  end

  it "does nothing when converting to the same currency" do
    1.usd.to_usd.must_equal 1
  end

  describe "operators" do

    before do
      mock_xavier_api(Time.now)
    end

    describe "#add" do
      it "adds two money expressions" do
        (1.eur + 1.27.usd).must_equal 2
        (1.27.usd + 1.eur).must_equal 2.54
        (1.eur + 1.eur).must_equal 2
      end

      it "does not affect non-money expressions" do
        (1 + 1.27).must_equal 2.27
        (38.eur + 1.27).must_equal 39.27
        (1.27.usd + 38).must_equal 39.27
        (2.27 + 1.usd).must_equal 3.27
        (2 + 1.usd).must_equal 3
      end

      describe "in a particular historical date" do
        it "works as well" do
          the_past = Time.parse('2010-08-25')
          mock_xavier_api(the_past)
          (2.eur.at(the_past) + 2.usd.at(the_past)).must_equal 3.58
        end
      end

    end

    describe "#-" do
      it "subtracts two money expressions" do
        (1.eur - 1.27.usd).must_equal 0
        (1.27.usd - 1.eur).must_equal 0
        (1.eur - 1.eur).must_equal 0
      end

      it "does not affect non-money expressions" do
        (1 - 1.27).must_equal -0.27
        (38.eur - 1.27).must_equal 36.73
        (1.27.usd - 38).must_equal -36.73
        (3.27 - 2.usd).must_equal 1.27
        (2 - 1.usd).must_equal 1
      end

      describe "in a particular historical date" do
        it "works as well" do
          the_past = Time.parse('2010-08-25')
          mock_xavier_api(the_past)
          (2.eur.at(the_past) - 2.usd.at(the_past)).must_be_close_to(0.42,0.1)
        end
      end

    end

  end

  describe "using XavierMedia API for exchange" do
    it "returns a converted amount from one currency to another" do
      mock_xavier_api(Time.now)
      2.eur.to_usd.must_equal 2.54
      2.usd.to_eur.must_equal 1.58
      2.gbp.to_usd.must_equal 3.07
    end

    it "raises a CurrencyNotFoundException given an invalid currency" do
      mock_xavier_api(Time.now)

      proc {1.usd.to_xxx}.must_raise(CurrencyNotFoundException)
    end

    it "raises a NoRatesFoundException if rate is 0.0 or non-existant" do
      mock_xavier_api(Time.now)

      proc {1.eur.to_rol}.must_raise(NoRatesFoundException)
    end

    describe "in a particular historical date" do

      before do
        @the_past = Time.parse('2010-08-25')
      end

      it "enhances instances of Numeric with :at method" do
        30.eur.must_respond_to(:at)
        proc { 30.usd.at("no date") }.must_raise(RuntimeError, "Must use 'at' with a time or date object")
        proc { 30.gbp.at(:whatever_arg) }.must_raise(RuntimeError, "Must use 'at' with a time or date object")
      end

      it "returns a converted amount from one currency to another in that particular date" do
        mock_xavier_api(@the_past)
        2.eur.at(@the_past).to_usd.must_equal 2.54
        2.usd.at(@the_past).to_eur.must_equal 1.58
        2.gbp.at(@the_past).to_usd.must_equal 3.07
      end

      it "retries yesterday and two days ago if no data found (could be a holiday)" do
        mock_xavier_api(@the_past, :fail => true)  # It's a holiday
        mock_xavier_api(@the_past - 86400, :fail => true)  # It's a holiday
        mock_xavier_api(@the_past - 86400 - 86400)  # It's a holiday

        2.eur.at(@the_past).to_usd.must_equal 2.54
      end

      it "raises an error when no data available" do
        counter = 0
        10.times do
          mock_xavier_api(@the_past - counter, :fail => true)  # It's a holiday
          counter += 86400
        end

        proc {
          begin 
            1.usd.at(@the_past).to_eur
          rescue NotFoundError=>e
            raise e
          rescue Timeout::Error
            retry
          end
        }.must_raise(NotFoundError)

      end

    end

    describe "when Rails (and its cache goodness) is present" do

      before do
        @now = Time.parse('2010-08-25')
        @the_past = Time.parse('2010-08-25')

        Rails = MiniTest::Mock.new unless defined?(Rails)
        @cache = MiniTest::Mock.new
        Rails.expect(:cache, @cache)

        mock_xavier_api(@the_past)
      end

      it "reads the exchange rate from the cache" do
        Rails.cache.expect(:read, 0.79, ['usd_eur_25-8-2010'])

        1.usd.at(@the_past).to_eur.must_equal 0.79
        2.usd.at(@the_past).to_eur.must_equal 1.58

        @cache.verify
      end

      it "caches the exchange rate with full precision" do
        Rails.cache.expect(:read, false, ['eur_jpy_25-8-2010'])

        Rails.cache.expect(:write, true, ['eur_jpy_25-8-2010', 107.07])
        1.eur.at(@the_past).to_jpy

        Rails.cache.expect(:write, true, ["eur_usd_25-8-2010", 1.268])
        1.eur.at(@the_past).to_usd

        Rails.cache.expect(:write, true, ["eur_huf_25-8-2010", 287.679993])
        2.eur.at(@the_past).to_huf

        @cache.verify
      end

      it "caches the XML response" do
        xml = Crack::XML.parse(fixture('xavier.xml'))["xavierresponse"]["exchange_rates"]["fx"]

        Rails.cache.expect(:read, false, ['eur_usd_25-8-2010'])
        Rails.cache.expect(:write, true, ['xaviermedia_25-8-2010', xml])

        1.eur.at(@the_past).to_usd

        @cache.verify
      end

      it "uses the base currency (EUR) cache to calculate other rates" do
        xml = Crack::XML.parse(fixture('xavier.xml'))["xavierresponse"]["exchange_rates"]["fx"]

        Rails.cache.expect(:read, false, ['eur_jpy_25-8-2010'])
        Rails.cache.expect(:write, true, ['xaviermedia_25-8-2010', xml])

        1.eur.at(@the_past).to_jpy.must_equal 107.07
        1.usd.at(@the_past).to_eur.must_equal 0.79
        1.eur.at(@the_past).to_gbp.must_equal 0.82
        2.gbp.at(@the_past).to_usd.must_equal 3.07

        @cache.verify
      end
    end
  end
end

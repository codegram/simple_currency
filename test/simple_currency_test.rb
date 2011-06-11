require 'test_helper'

describe "SimpleCurrency" do

  it "enhances instances of Numeric with currency methods" do
    30.must_respond_to :eur
    30.must_respond_to :usd
    30.must_respond_to :gbp
  end

  it "handles zero values (by returning them straight away)" do
    0.usd.to_eur.must_equal 0.0 
  end

  it "does nothing when converting to the same currency" do
    1.usd.to_usd.must_equal 1
  end

  describe "operators" do

    before :each do
      mock_xavier_api(Time.now)
    end

    describe "#+" do
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
          (2.eur.at(the_past) - 2.usd.at(the_past)).should be_close(0.42,0.1)
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
        proc { 30.eur.at(Time.now) }.to_not raise_error
        proc { 30.usd.at("no date")}.must_raise("Must use 'at' with a time or date object")
        proc { 30.gbp.at(:whatever_arg) }.must_raise("Must use 'at' with a time or date object")
      end

      it "returns a converted amount from one currency to another in that particular date" do
        mock_xavier_api(@the_past)
        2.eur.at(@the_past).to_usd.must_equal 2.54
        2.usd.at(@the_past).to_eur.must_equal 1.58
        2.gbp.at(@the_past).to_usd.must_equal 3.07
      end

      it "retries in case of timeout" do
        mock_xavier_api(@the_past, :timeout => 2)
        2.eur.at(@the_past).to_usd.must_equal 2.54
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

      before :each do
        @now = Time.parse('2010-08-25')
        @the_past = Time.parse('2010-08-25')
      end
      before(:all) do
        require 'rails'
      end

      before(:each) do
        Rails.stub_chain("cache.read").and_return(false)
        Rails.stub_chain("cache.write").and_return(true)

        mock_xavier_api(@the_past)
      end

      it "reads the exchange rate from the cache" do
        Rails.stub_chain("cache.read").with('usd_eur_25-8-2010').and_return(0.79)

        URI.should_not_receive(:parse)
        1.usd.at(@the_past).to_eur.must_equal 0.79
        2.usd.at(@the_past).to_eur.must_equal 1.58
      end

      it "caches the exchange rate with full precision" do
        Rails.cache.expect(:write).with('eur_jpy_25-8-2010', 107.07).ordered
        Rails.cache.expect(:write).with("eur_usd_25-8-2010", 1.268).ordered
        Rails.cache.expect(:write).with("eur_huf_25-8-2010", 287.679993).ordered

        1.eur.at(@the_past).to_jpy
        1.eur.at(@the_past).to_usd
        2.eur.at(@the_past).to_huf
      end

      it "caches the XML response" do
        Rails.cache.expect(:write).with('xaviermedia_25-8-2010', an_instance_of(Array)).and_return(true)

        1.eur.at(@the_past).to_usd
      end

      it "uses the base currency (EUR) cache to calculate other rates" do
        1.eur.at(@the_past).to_jpy.must_equal 107.07

        Rails.stub_chain("cache.read").with('xaviermedia_25-8-2010').and_return(Crack::XML.parse(fixture('xavier.xml'))["xavierresponse"]["exchange_rates"]["fx"])

        URI.should_not_receive(:parse)

        1.usd.at(@the_past).to_eur.must_equal 0.79
        1.eur.at(@the_past).to_gbp.must_equal 0.82
        2.gbp.at(@the_past).to_usd.must_equal 3.07
      end
    end
  end
end

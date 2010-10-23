require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "SimpleCurrency" do

  it "enhances instances of Numeric with currency methods" do
    expect { 30.eur && 30.usd && 30.gbp }.to_not raise_error
  end

  it "handles zero values (by returning them straight away)" do
    0.usd.to_eur.should == 0.0 
  end

  describe "operators" do

    let(:today) { Time.now }

    before(:each) do
      mock_xavier_api(today)
    end

    describe "#+" do
      it "adds two money expressions" do
        (1.eur + 1.27.usd).should == 2
        (1.27.usd + 1.eur).should == 2.54
        (1.eur + 1.eur).should == 2
      end

      it "does not affect non-money expressions" do
        (1 + 1.27).should == 2.27
        (38.eur + 1.27).should == 39.27
        (1.27.usd + 38).should == 39.27
      end
    end

    describe "#-" do
      it "subtracts two money expressions" do
        (1.eur - 1.27.usd).should == 0
        (1.27.usd - 1.eur).should == 0
        (1.eur - 1.eur).should == 0
      end

      it "does not affect non-money expressions" do
        (1 - 1.27).should == -0.27
        (38.eur - 1.27).should == 36.73
        (1.27.usd - 38).should == -36.73
      end
    end

  end

  context "using XavierMedia API for exchange" do

    let(:today) { Time.now }

    it "returns a converted amount from one currency to another" do
      mock_xavier_api(today)
      2.eur.to_usd.should == 2.54
      2.usd.to_eur.should == 1.58
      2.gbp.to_usd.should == 3.07
    end

    it "raises a CurrencyNotFoundException given an invalid currency" do
      mock_xavier_api(today)

      expect {1.usd.to_xxx}.to raise_error(CurrencyNotFoundException)
    end

    it "raises a NoRatesFoundException if rate is 0.0 or non-existant" do
      mock_xavier_api(today)

      expect {1.eur.to_rol}.to raise_error(NoRatesFoundException)
    end

    context "in a particular historical date" do

      let(:the_past) { Time.parse('2010-08-25')}
      let(:the_ancient_past) { Time.parse('1964-08-25')}

      it "enhances instances of Numeric with :at method" do
        expect { 30.eur.at(Time.now) }.to_not raise_error
        expect { 30.usd.at("no date")}.to raise_error("Must use 'at' with a time or date object")
        expect { 30.gbp.at(:whatever_arg) }.to raise_error("Must use 'at' with a time or date object")
      end

      it "returns a converted amount from one currency to another in that particular date" do
        mock_xavier_api(the_past)
        2.eur.at(the_past).to_usd.should == 2.54
        2.usd.at(the_past).to_eur.should == 1.58
        2.gbp.at(the_past).to_usd.should == 3.07
      end

      it "retries in case of timeout" do
        mock_xavier_api(the_past, :timeout => 2)
        2.eur.at(the_past).to_usd.should == 2.54
      end

      it "retries yesterday and two days ago if no data found (could be a holiday)" do
        mock_xavier_api(the_past, :fail => true)  # It's a holiday
        mock_xavier_api(the_past - 86400, :fail => true)  # It's a holiday
        mock_xavier_api(the_past - 86400 - 86400)  # It's a holiday

        2.eur.at(the_past).to_usd.should == 2.54
      end

      it "raises an error when no data available" do
        counter = 0
        10.times do
          mock_xavier_api(the_past - counter, :fail => true)  # It's a holiday
          counter += 86400
        end

        expect {
          begin 
            1.usd.at(the_past).to_eur
          rescue NotFoundError=>e
            raise e
          rescue Timeout::Error
            retry
          end
        }.to raise_error(NotFoundError)

      end

    end

    context "when Rails (and its cache goodness) is present" do

      let(:now) { Time.parse('2010-08-30') }
      let(:the_past) { Time.parse('2010-08-25') }

      before(:all) do
        require 'rails'
      end

      before(:each) do
        Rails.stub_chain("cache.read").and_return(false)
        Rails.stub_chain("cache.write").and_return(true)

        mock_xavier_api(the_past)
      end

      it "reads the exchange rate from the cache" do
        Rails.stub_chain("cache.read").with('usd_eur_25-8-2010').and_return(0.79)

        URI.should_not_receive(:parse)
        1.usd.at(the_past).to_eur.should == 0.79
        2.usd.at(the_past).to_eur.should == 1.58
      end

      it "caches the exchange rate with full precision" do
        Rails.cache.should_receive(:write).with('eur_jpy_25-8-2010', 107.07).ordered
        Rails.cache.should_receive(:write).with("eur_usd_25-8-2010", 1.268).ordered
        Rails.cache.should_receive(:write).with("eur_huf_25-8-2010", 287.679993).ordered

        1.eur.at(the_past).to_jpy
        1.eur.at(the_past).to_usd
        2.eur.at(the_past).to_huf
      end

      it "caches the XML response" do
        Rails.cache.should_receive(:write).with('xaviermedia_25-8-2010', an_instance_of(Array)).and_return(true)

        1.eur.at(the_past).to_usd
      end

      it "uses the base currency (EUR) cache to calculate other rates" do
        1.eur.at(the_past).to_jpy.should == 107.07

        Rails.stub_chain("cache.read").with('xaviermedia_25-8-2010').and_return(Crack::XML.parse(fixture('xavier.xml'))["xavierresponse"]["exchange_rates"]["fx"])

        URI.should_not_receive(:parse)

        1.usd.at(the_past).to_eur.should == 0.79
        1.eur.at(the_past).to_gbp.should == 0.82
        2.gbp.at(the_past).to_usd.should == 3.07
      end

    end

  end


end

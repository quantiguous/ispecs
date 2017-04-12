require_relative 'matcher'
require 'sqlite3'

class FundsTransferByCustomerService2
  def initialize
    @env = ::ApiBanking::Environment::LOCAL.new('10.211.55.6', 7800)
  end
  
  def getBalance(appID, customerID, accountNo)
    request = ApiBanking::FundsTransferByCustomerService2::GetBalance::Request.new()

    request.appID = appID
    request.customerID = customerID
    request.AccountNumber = accountNo
    
    ApiBanking::FundsTransferByCustomerService2.get_balance(@env, request)
  end
end

module Flexcube
  class Exception
    @db = SQLite3::Database.new("./db/test.db")
    @xml_doc = Nokogiri::XML(File.read('./fixtures/Exception.xml'))
  end
end

class CasaAccountBalanceInquiryResponse
  def initialize
    @db = SQLite3::Database.new("./db/test.db")
    @xml_doc = Nokogiri::XML(File.read('./fixtures/CasaAccountBalanceInquiryResponse.xml'))
  end
  
  def AvailableBalance=(val)    
    @xml_doc.at_xpath('//AvailableBalance').content = val
    save
  end
  
  def AvailableBalance
    BigDecimal.new(@xml_doc.at_xpath('//AvailableBalance').content)
  end
  
  private
  
  def save
    @db.execute("update replies set reply = ? where op = ?", @xml_doc.to_s, 'CasaAccountBalanceInquiryResponse')
  end
  
end


describe FundsTransferByCustomerService2 do  
  let (:ft2) { FundsTransferByCustomerService2.new }
  let (:flex) { CasaAccountBalanceInquiryResponse.new }
  
  context "getBalance" do
    context "for an account" do
      # setup the flex response that will be sent to the service
          
      it "should return the account balance" do
        flex.AvailableBalance = 1003
        resp = ft2.getBalance('12345', '2424', '000190600002003')
        expect(resp.accountBalanceAmount).to eq(flex.AvailableBalance)
      end
    end

    # context "for a non-existant account" do
    #   # setup the flex response that will be sent to the service
    #
    #   it "should return fault" do
    #     flex.AvailableBalance = 1003
    #     resp = ft2.getBalance('12345', '2424', '000190600002003')
    #     expect(resp.accountBalanceAmount).to eq(flex.AvailableBalance)
    #   end
    # end

  end
end

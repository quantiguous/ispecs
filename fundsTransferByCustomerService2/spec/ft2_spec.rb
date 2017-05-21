require_relative 'matcher'
require 'sqlite3'

class FundsTransferByCustomerService2
  def initialize
    @env = ::ApiBanking::Environment::LOCAL.new('10.211.55.3', 7800)
  end
  
  def getBalance(appID, customerID, accountNo)
    request = ApiBanking::FundsTransferByCustomerService2::GetBalance::Request.new()

    request.appID = appID
    request.customerID = customerID
    request.AccountNumber = accountNo
    
    ApiBanking::FundsTransferByCustomerService2.get_balance(@env, request)
  end
  
  def transfer(appID, customerID, accountNo)
    address = ApiBanking::FundsTransferByCustomerService2::Transfer::Address.new()
    beneficiary = ApiBanking::FundsTransferByCustomerService2::Transfer::Beneficiary.new()
    request = ApiBanking::FundsTransferByCustomerService2::Transfer::Request.new()
    
    address.address1 = 'Mumbai'

    beneficiary.fullName = 'Quantiguous Solutions'
    beneficiary.accountNo = '00001234567890'
    beneficiary.accountIFSC = 'RBIB0123456'
    beneficiary.address = address  # can also be a string

    request.uniqueRequestNo = SecureRandom.uuid.gsub!('-','')
    request.appID = appID
    request.purposeCode = 'PC01'
    request.customerID = customerID
    request.debitAccountNo = accountNo
    request.transferType = 'NEFT'
    request.transferAmount = 20
    request.remitterToBeneficiaryInfo = 'FUND TRANSFER'

    request.beneficiary = beneficiary
    
    ApiBanking::FundsTransferByCustomerService2.transfer(@env, request)        
  end
  
end

class Exception
  def initialize
    @db = SQLite3::Database.new("./db/test.db")
    @xml_doc = Nokogiri::XML(File.read('./fixtures/Exception.xml'))
  end
  
  def ErrorCode=(val)
    @xml_doc.at_xpath('//ErrorCode').content = val
    save
  end
  
  def ErrorCode
    @xml_doc.at_xpath('//ErrorCode').content
  end  

  private
  
  def save
    @db.execute("update replies set reply = ?", @xml_doc.to_s)
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
    @db.execute("update replies set reply = ?", @xml_doc.to_s)
  end
  
end


describe FundsTransferByCustomerService2 do  
  let (:ft2) { FundsTransferByCustomerService2.new }
  let (:casaAccountBalanceInquiryResponse) { CasaAccountBalanceInquiryResponse.new }
  let (:ex) { Exception.new }
  
  context "getBalance" do
    context "for an account" do
      # setup the flex response that will be sent to the service
          
      it "should return the account balance" do
        casaAccountBalanceInquiryResponse.AvailableBalance = 1003
        resp = ft2.getBalance('12345', '2424', '000190600002003')
        expect(resp.accountBalanceAmount).to eq(casaAccountBalanceInquiryResponse.AvailableBalance)
      end
    end

    context "for a non-existant account" do
      # setup the flex response that will be sent to the service
            
      it "should return fault" do
        ex.ErrorCode = "2778"
        resp = ft2.getBalance('12345', '2424', '000190600002003')
        expect(resp.code).to eq("flex:E#{ex.ErrorCode}")
      end
    end
  end
  
  context "transfer" do
    it "should do transfer" do
      p ft2.transfer('12345', '2424', '000190600002003')
    end
  end
  
end

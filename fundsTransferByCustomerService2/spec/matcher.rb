require 'rspec/expectations'

RSpec::Matchers.define :be_equivalent_to do |rep|
  match do |r|
    expect(r.accountBalanceAmount).to eq(rep.AvailableBalance)
  end
  
  failure_message do |r|
    "i got : #{r}"
  end  
end

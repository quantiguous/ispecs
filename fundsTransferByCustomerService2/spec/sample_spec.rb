class Sample
  def self.post(data)
    conn = Faraday.new(:url => 'http://localhost:9292')
    conn.post '/', data
  end
end

describe Sample do
  context 'send data' do
    it 'should do something' do
      p Sample.post('<abc/>').body
      p Sample.post('<abc/>').body      
    end
  end
end
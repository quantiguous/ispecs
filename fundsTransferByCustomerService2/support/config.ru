require 'sqlite3'
require 'fileutils'

class Application
  def initialize
    FileUtils.rm('test.db', force: true)
    @db = SQLite3::Database.new "../db/test.db"
    # Create a table
    rows = @db.execute <<-SQL
      create table replies (
        op text,
        reply text
      );
    SQL
    
    @db.execute("INSERT INTO replies ( op, reply ) VALUES ( ?, ? )", ['CasaAccountBalanceInquiryResponse', nil])    
  end

  def call(env)
    request = Rack::Request.new env

    reply = @db.get_first_value( "select reply from replies where op = ? ", 'CasaAccountBalanceInquiryResponse')
    
    p reply
    
    status  = 200
    headers = { "Content-Type" => "text/xml" }
    body    = [reply]

    [status, headers, body]
  end

end

run Application.new

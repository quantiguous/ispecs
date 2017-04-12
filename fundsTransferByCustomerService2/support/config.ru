require 'sqlite3'
require 'fileutils'

class Application
  def initialize
    FileUtils.rm('test.db', force: true)
    @db = SQLite3::Database.new "test.db"
    # Create a table
    rows = @db.execute <<-SQL
      create table log (
        id integer primary key autoincrement,
        req text
      );
    SQL
  end

  def call(env)
    request = Rack::Request.new env
    p request.body.read
    status  = 200
    headers = { "Content-Type" => "text/html" }
    body    = ["Yay, your first web application! <3"]

    [status, headers, body]
  end
end

run Application.new

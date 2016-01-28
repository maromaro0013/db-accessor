require 'yaml'
require "net/ssh/gateway"
require "mysql2"
require "active_record"

gateway = Net::SSH::Gateway.new('nrdb-01.gbnet', 'root', :port => 22, :password => ENV["ROOT_PASSWD"])
if !gateway.active?
  p "connection failed"
  return
end

class Ppv < ActiveRecord::Base
  self.table_name = 'ppv_menu'
end

gateway.open("localhost", 3306) {|local_port|
  db = YAML.load_file('./database.yml')
  db["haru"]["port"] = local_port
  ActiveRecord::Base.establish_connection(db["haru"])

  #puts ActiveRecord::Base.connection.tables
  c = Ppv.find "001"
  puts c.title

=begin
  ActiveRecord::Base.connection.tables.each {|table_name|
    puts table_name
  }
=end
=begin
  client = Mysql2::Client.new(
    host: '127.0.0.1',
    port: local_port,

    username: 'dba',
    password: '',
    database: 'haru'
  )

  client.query('SHOW TABLES;').each do |row|
    p row
  end
=end
}

=begin
port = gateway.open('127.0.0.1', 3306, 3307)

db = YAML.load_file('./database.yml')
db["haru"]["port"] = port
ActiveRecord::Base.establish_connection(db["haru"])
#puts db
#ActiveRecord::Base.connection.tables

class Menu < ActiveRecord::Base
  self.table_name = 'menu'
end
=end

#puts Menu.find 1

gateway.shutdown!

=begin
db = YAML.load_file('./database.yml')
ActiveRecord::Base.establish_connection(db["haru"])

class Menu < ActiveRecord::Base
  self.table_name = 'menu'
end

puts Menu.find 1
=end

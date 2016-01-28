require 'yaml'
require "net/ssh/gateway"
require "mysql2"
require "active_record"

db = YAML.load_file('./database.yml')
contents = YAML.load_file('./contents.yml')
date_range = range = Time.new(2015, 12, 1, 0, 0, 0)..Time.new(2015, 12, 31, 23, 59, 59)

puts contents

gateway = Net::SSH::Gateway.new('sadb-01', 'wwwuser', :port => 22, :password => ENV["WWWUSER_PASSWD"])
if !gateway.active?
  p "connection failed"
  return
end

class AdcodeSubscribeLasts < ActiveRecord::Base
  self.table_name = 'adcode_subscribe_lasts'
  self.readonly
end

gateway.open("localhost", 3306) {|local_port|
  db["sadb-01"]["port"] = local_port
  db["sadb-01"]["database"] = "swan_analyze"
  ActiveRecord::Base.establish_connection(db["sadb-01"])

=begin
  c = AdcodeSubscribeLasts.where(date: date_range).where("adcode1 like ?", "pr=menulistad")
  c.each {|record|
    puts record.uid
  }
}
=end

gateway = Net::SSH::Gateway.new('nrdb-01.gbnet', 'root', :port => 22, :password => ENV["ROOT_PASSWD"])
if !gateway.active?
  p "connection failed"
  return
end

class Ppv < ActiveRecord::Base
  self.table_name = 'ppv_menu'
  self.readonly
end

class AdcodeRegist < ActiveRecord::Base
  self.table_name = 'adcode_regist'
  self.readonly
end

gateway.open("localhost", 3306) {|local_port|
  db["nrdb-01.gbnet"]["port"] = local_port
  db["nrdb-01.gbnet"]["database"] = "angey"
  ActiveRecord::Base.establish_connection(db["nrdb-01.gbnet"])

  #puts ActiveRecord::Base.connection.tables
  #c = Ppv.find "001"
  #c = AdcodeRegist.find 1
  #c = AdcodeRegist.where("query like ?", "pr=menulistad")
  #puts c.title
}

gateway.shutdown!

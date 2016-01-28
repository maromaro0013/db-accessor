require 'yaml'
require "net/ssh/gateway"
require "mysql2"
require "active_record"

contents = YAML.load_file('./contents.yml')
adcords = YAML.load_file('./adcords.yml')
date_range = range = Time.new(2015, 12, 1, 0, 0, 0)..Time.new(2015, 12, 31, 23, 59, 59)

adcode_uids = adcords

gateway = Net::SSH::Gateway.new('sadb-01', 'wwwuser', :port => 22, :password => ENV["WWWUSER_PASSWD"])
if !gateway.active?
  p "connection failed"
  return
end

class AdcodeSubscribeLasts < ActiveRecord::Base
  self.table_name = 'adcode_subscribe_lasts'
  self.readonly
end
class Ppv < ActiveRecord::Base
  self.table_name = 'ppv'
  self.readonly
end

def getPaymentsFromPpv(uids)
  db = YAML.load_file('./database.yml')
  gateway = Net::SSH::Gateway.new('nrdb-01.gbnet', 'root', :port => 22, :password => ENV["ROOT_PASSWD"])
  if !gateway.active?
    p "connection failed"
    return
  end

  gateway.open("localhost", 3306) {|local_port|
    db["nrdb-01.gbnet"]["port"] = local_port
    db["nrdb-01.gbnet"]["database"] = "haru"
    ActiveRecord::Base.establish_connection(db["nrdb-01.gbnet"])

=begin
    uid = "https://id.my.softbank.jp/service/idp/server.php/idpage?id=e4sb2boukr3r7crsa5lj8sarkcb1r34b3e676m16i6du1t9t9f0i2doah4nefstj"
    q = Ppv.where(uid: uid)
    puts q.count
=end

  q = Ppv.arel_table[:uid]
  uid_sel = q.matches("")
  uids.each {|uid|
    uid_sel = uid_sel.or(q.matches(uid))
    #q = q.or(q.where(uid: uid))
  }
  #uid_sel = q.matches(uid)
  ret = Ppv.where(uid_sel).pluck(:menuid)
  puts ret.length
=begin
    q = Ppv.where(uid: "")
    uids.each {|uid|
      q = q.or(q.where(uid: uid))
    }
    puts q.count
=end
  }
  gateway.shutdown!
end

gateway.open("localhost", 3306) {|local_port|
  db = YAML.load_file('./database.yml')
  db["sadb-01"]["port"] = local_port
  db["sadb-01"]["database"] = "swan_analyze"
  ActiveRecord::Base.establish_connection(db["sadb-01"])

  adcode_uids = {}
  adcords.each {|adcord|
    adcode_uids[adcord] = []
    q = AdcodeSubscribeLasts.where(date: date_range).where("adcode1 like ?", adcord)
    adcode_uids[adcord] = q.pluck(:uid)
  }
  #puts adcode_uids["pr=menulistad"].length
}

gateway.shutdown!

uids = ["https://id.my.softbank.jp/service/idp/server.php/idpage?id=e4sb2boukr3r7crsa5lj8sarkcb1r34b3e676m16i6du1t9t9f0i2doah4nefstj",
        "https://connect.auone.jp/net/id/hny_rt_net/cca/s/XBg1dJnhlDs1Ngwg/Xcmri4AY_IntcfBL"]
getPaymentsFromPpv(uids)

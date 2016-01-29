require 'yaml'
require "net/ssh/gateway"
require "mysql2"
require "active_record"
require 'pp'

@db = YAML.load_file('./database.yml')
contents = YAML.load_file('./contents.yml')
adcords = YAML.load_file('./adcords.yml')
@date_range = range = Time.new(2015, 12, 1, 0, 0, 0)..Time.new(2015, 12, 31, 23, 59, 59)

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
class AnalyzePpvAll < ActiveRecord::Base
  self.table_name = 'analyze_ppv_all'
  self.readonly
end

=begin
class Ppv < ActiveRecord::Base
  self.table_name = 'ppv'
  self.readonly
end
def getPaymentsFromPpv(uids)
  gateway = Net::SSH::Gateway.new('nrdb-01.gbnet', 'root', :port => 22, :password => ENV["ROOT_PASSWD"])
  if !gateway.active?
    p "connection failed"
    return
  end

  gateway.open("localhost", 3306) {|local_port|
    @db["nrdb-01.gbnet"]["port"] = local_port
    @db["nrdb-01.gbnet"]["database"] = "haru"
    ActiveRecord::Base.establish_connection(@db["nrdb-01.gbnet"])

    q = Ppv.arel_table[:uid]
    uid_sel = q.matches("")
    uids.each {|uid|
      uid_sel = uid_sel.or(q.matches(uid))
    }
    ret = Ppv.where(startdate: @date_range).where(uid_sel).pluck(:menuid)

    payment_amount = 0
    ret.each
    puts ret.length
  }
  gateway.shutdown!
end
=end

gateway.open("localhost", 3306) {|local_port|
  @db = YAML.load_file('./database.yml')
  @db["sadb-01"]["port"] = local_port
  @db["sadb-01"]["database"] = "swan_analyze"
  ActiveRecord::Base.establish_connection(@db["sadb-01"])

  adcode_uids = {}
  adcode_payments = {}
  adcode_amount = {}

  adcords.each {|adcord|
    adcode_uids[adcord] = []
    q = AdcodeSubscribeLasts.where(date: @date_range).where("adcode1 like ?", adcord)
    adcode_uids[adcord] = q.pluck(:uid)
    #puts adcode_uids[adcord].length

    adcode_payments[adcord] = []
    adcode_amount[adcord] = 0
  }

  adcords.each {|adcord|
    adcode_uids[adcord].each {|uid|
      ret = AnalyzePpvAll.where(start_date: @date_range).where("uid = ?", uid).select(:uid, :site_id, :menuid, :start_date, :charge)
      if ret.length > 0
        #adcode_payments[adcord] << ret
        ret.each{|r|
          adcode_amount[adcord] += r.charge
        }
      end
    }
  }

  adcode_amount.each {|amt|
    puts amt
  }
}

gateway.shutdown!

require 'yaml'
require "net/ssh/gateway"
require "mysql2"
require "active_record"
require 'pp'

@db = YAML.load_file('./database.yml')
adcords = YAML.load_file('./adcords.yml')
@date_range = range = Time.gm(2016, 2, 1, 0, 0, 0)..Time.gm(2016, 2, 29, 23, 59, 59)
CARRIERS = {'docomo' => 1, 'au' => 2, 'softbank' => 3, 'sp_docomo' => 6, 'sp_au' => 7, 'sp_softbank' => 9}

adcode_uids = adcords

@gateway = Net::SSH::Gateway.new('sadb-01', 'wwwuser', :port => 22, :password => ENV["WWWUSER_PASSWD"])
if !@gateway.active?
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
class Sites < ActiveRecord::Base
  self.table_name = 'sites'
  self.readonly
end
class AnalyzeMembers < ActiveRecord::Base
  self.table_name = 'analyze_members'
  self.readonly
end

# 8115
def get_monthly_payment_users
  @gateway.open("localhost", 3306) {|local_port|
    @db = YAML.load_file('./database.yml')
    @db["sadb-01"]["port"] = local_port
    @db["sadb-01"]["database"] = "swan_analyze"
    ActiveRecord::Base.establish_connection(@db["sadb-01"])

    sites = YAML.load_file('./sites.yml')
    site_ids = {}
    sites.each{|site|
      site_ids[site] = Sites.where(site: site)[0].id
    }

    # 月の全体ユーザー従量購入者数(#10359)
=begin
    site_users = {}
    site_ids.each{|site, id|
      site_users[site] = AnalyzePpvAll.where(start_date: @date_range).where(site_id: id).pluck(:uid)
      site_users[site] = site_users[site].uniq
    }
    puts "payment_users," + site_users["haru"].count.to_s
    puts "------"
=end
    # 月の全体ユーザー従量購入者数(キャリアごと)(#10359)
    amount = 0
    site_users = {}
    site_ids.each{|site, id|
      site_users[site] = {}
      CARRIERS.each{|name, carrier_id|
        site_users[site][name] = AnalyzePpvAll.where(start_date: @date_range).where(site_id: id, carrier_id: carrier_id).pluck(:uid)
        site_users[site][name] = site_users[site][name].uniq
        amount += site_users[site][name].count
        puts name + "," + site_users[site][name].count.to_s
      }
    }
    puts "amount," + amount.to_s

    puts "------"
    # 月の入会者を取得
    site_subscribes = {}
    site_ids.each{|site, id|
      site_subscribes[site] = {}
      CARRIERS.each{|name, carrier_id|
        site_subscribes[site][name] = AnalyzeMembers.where(subscribe_date: @date_range).where(site_id: id, carrier_id: carrier_id).pluck(:uid)
        site_subscribes[site][name] = site_subscribes[site][name].uniq
        puts name + "," + site_subscribes[site][name].count.to_s
      }
    }

    # 月の新規ユーザー従量購入者数
    amount = 0
    payment_users = {}
    site_ids.each{|site, id|
      puts "---" + site + "---"
      payment_users[site] = {}
      CARRIERS.each{|name, carrier_id|
        payment_users[site][name] = site_users[site][name] & site_subscribes[site][name]
        amount += payment_users[site][name].count
        puts name + "," + payment_users[site][name].count.to_s
      }
      puts "amount," + amount.to_s
      puts "------"
    }

    # 新規ユーザー従量購入額
    payment_amounts = {}
    payment_users.each{|site, ids|
      site_id = site_ids[site]
      amount = 0

      ids.each {|carrer, ary|
        ary.each{|id|
          ret = AnalyzePpvAll.where(start_date: @date_range).where(site_id: site_id).where(uid: id).pluck(:charge)
          amount += ret.inject(:+)
        }
      }

      payment_amounts[site] = amount
      puts payment_amounts[site]
    }

=begin
    # 月の入会者を取得
    site_subscribes = {}
    site_ids.each{|site, id|
      site_subscribes[site] = AnalyzeMembers.where(subscribe_date: @date_range).where(site_id: id).pluck(:uid)
      #puts site_subscribes[site].length
    }

    # 月の新規ユーザー従量購入者数
    payment_users = {}
    site_ids.each{|site, id|
      payment_users[site] = site_subscribes[site] & site_users[site]
      #puts payment_users[site].length
    }

    # 新規ユーザー従量購入額
    payment_amounts = {}
    payment_users.each{|site, ids|
      site_id =  site_ids[site]
      amount = 0
      ids.each{|id|
        ret = AnalyzePpvAll.where(start_date: @date_range).where(site_id: site_id).where(uid: id).pluck(:charge)
        amount += ret.inject(:+)
      }
      payment_amounts[site] = amount
      puts payment_amounts[site]
    }
=end
  }
  @gateway.shutdown!

  #q = AdcodeSubscribeLasts.where(date: @date_range).where("adcode1 like ?", adcord)
end

get_monthly_payment_users()

=begin
@gateway.open("localhost", 3306) {|local_port|
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
    adcode_payments[adcord] = []
    adcode_amount[adcord] = 0
  }

  adcords.each {|adcord|
    adcode_uids[adcord].each {|uid|
      ret = AnalyzePpvAll.where(start_date: @date_range).where("uid = ?", uid).select(:uid, :site_id, :menuid, :start_date, :charge)
      if ret.length > 0
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
=end

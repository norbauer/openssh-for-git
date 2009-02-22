#!/usr/bin/ruby

# logging is inefficient - recommended to use for testing only
LOGGING = true
LOGFILE = File.join(File.dirname(__FILE__), 'authorized_script_log')

# if we're logging, set up log file in advance
if LOGGING
  begin
    LOG = File.open(LOGFILE, 'a')
    at_exit { LOG.close }
  rescue SystemCallError
    LOG = nil
  end
end

def log(msg)
  # still recommend adding "if LOGGING" to your log statements for performance reasons
  LOG.puts "[#{Time.now}] #{msg}" if LOG
end

key = STDIN.gets
log("trying to authorize key: #{key}") if LOGGING

unless key =~ /^ssh-(?:dss|rsa) [A-Za-z0-9+\/]+$/
  log("[ERROR] invalid key!") if LOGGING
  Kernel.exit(1)
end

# Only load mysql if we validated the key
# mysql is a fairly substantial library, and so it may be faster to change
# this to a simple API call to an already running service.
require 'rubygems'
gem 'mysql'
require 'mysql'

user = nil
begin
  mysql = Mysql.connect('localhost', 'username', 'password', 'database')
  at_exit { mysql.close }
  mysql.query("SELECT username FROM user_keys WHERE key = '#{Mysql.quote(key)}' LIMIT 2") do |result|
    case result.num_rows
    when 0
      log("key not found") if LOGGING
      Kernel.exit(1)
    when 1
      user = result.fetch_row.first
      log("user found: #{user}") if LOGGING
    when 2
      log("[ERROR] Key is not unique in the database!") if LOGGING
      Kernel.exit(1)
    end
  end
rescue Mysql::Error => e
  log("[ERROR] #{e.class}: #{e.to_s}") if LOGGING
  Kernel.exit(1)
end

# there is an assumption here is that 'user' is a safe value
STDOUT.print %Q[command="gitosis-serve #{user}",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty]

Kernel.exit(0)

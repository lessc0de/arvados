#!/usr/bin/env ruby

abort 'Error: Ruby >= 1.9.3 required.' if RUBY_VERSION < '1.9.3'

require 'logger'
require 'trollop'

log = Logger.new STDERR
log.progname = $0.split('/').last

opts = Trollop::options do
  banner ''
  banner "Usage: #{log.progname} " +
    "{user_uuid_or_email} {user_and_repo_name} {vm_uuid}"
  banner ''
  opt :debug, <<-eos
Show debug messages.
  eos
  opt :openid_prefix, <<-eos, default: 'https://www.google.com/accounts/o8/id'
If creating a new user record, require authentication from an OpenID \
with this OpenID prefix *and* a matching email address in order to \
claim the account.
  eos
end

default_openid_prefix = 'https://www.google.com/accounts/o8/id'

log.level = (ENV['DEBUG'] || opts.debug) ? Logger::DEBUG : Logger::WARN
    
if ARGV.count != 3
  Trollop::die "required arguments are missing"
end

user_arg, user_repo_name, vm_uuid = ARGV

require 'arvados'
arv = Arvados.new(api_version: 'v1')

# Look up the given user by uuid or, failing that, email address.
begin
  found_user = arv.user.get(uuid: user_arg)
rescue Arvados::TransactionFailedError
  found = arv.user.list(where: {email: ARGV[0]})[:items]
    
  if found.count == 0 
    if !user_arg.match(/\w\@\w+\.\w+/)
      abort "About to create new user, but #{user_arg.inspect} " +
               "does not look like an email address. Stop."
    end
  elsif found.count != 1
    abort "Found #{found.count} users " +
              "with uuid or email #{user_arg.inspect}. Stop."
  else
    found_user = found.first
  end
end

# Invoke user setup method 
if (found_user)
  user = {uuid: found_user[:uuid]}
else
  user = {email: user_arg}
end

if opts.openid_prefix
  puts "used the -o option"
end

if opts.openid_prefix == default_openid_prefix
  user = arv.user.setup user: user, repo_name: user_repo_name, vm_uuid: vm_uuid
else
  user = arv.user.setup user: user, repo_name: user_repo_name, vm_uuid: vm_uuid,
      openid_prefix: opts.openid_prefix
end

log.info {"user uuid: " + user[:uuid]}

puts user.inspect


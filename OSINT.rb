#!/usr/bin/env ruby
# -----------------------------------------------------------------------------
# URL checker will perform OSINT using static URLs for known internet facing app
# -----------------------------------------------------------------------------
# RubyOSINT v1
# Thanks to @carnalOwnage for the idea and some code. Also Alex for the Ruby foo.

require 'uri'
require 'net/http'
require 'net/https'
require 'optparse'

class String
  def black;    "\033[30m#{self}\033[0m" end
  def red;      "\033[31m#{self}\033[0m" end
  def green;    "\033[32m#{self}\033[0m" end
  def brown;    "\033[33m#{self}\033[0m" end
  def blue;     "\033[34m#{self}\033[0m" end
  def magenta;     "\033[35m#{self}\033[0m" end
  def cyan;     "\033[36m#{self}\033[0m" end
  def gray;     "\033[37m#{self}\033[0m" end
  def bg_black;    "\033[40m#{self}\033[0m" end
  def bg_red;      "\033[41m#{self}\033[0m" end
  def bg_green;    "\033[42m#{self}\033[0m" end
  def bg_brown;    "\033[43m#{self}\033[0m" end
  def bg_blue;     "\033[44m#{self}\033[0m" end
  def bg_magenta;  "\033[45m#{self}\033[0m" end
  def bg_cyan;     "\033[46m#{self}\033[0m" end
  def bg_gray;     "\033[47m#{self}\033[0m" end
  def bold;     "\033[1m#{self}\033[22m" end
  def reverse_color;  "\033[7m#{self}\033[27m" end
end
# -----------------------------------------------------------------------------

options = {}

optparse = OptionParser.new do |opts|

  opts.banner = "Usage: OSINT.rb --url URL --uri URIS"

  options[:url] = nil
  opts.on('--url URL','Website to test') do |url|
    options[:url] = url
  end

  options[:uri] = nil
  opts.on('--uri URIS','URIs to check') do |uri|
    options[:uri] = uri
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
optparse.parse!

if options[:url].nil?
  puts optparse
  exit
end

if options[:uri].nil?
  puts optparse
  exit
end

site = options[:url]
puts "The target domain in scope is:" +  " #{site} .".bold.blue
puts " "
puts "Dumping web server headers: ".bold.gray.bg_red
# -----------------------------------------------------------------------------
# This section goes and gets the HTTP headers and returns them
 domain = URI(site) # we have to run the target through URI to get only the domain.
 host = domain.host #here we use URI .host to get domain only to feed NET.start
 http = Net::HTTP.start(host) # makes the HTTP request 
 resp = http.head('/')
 resp.each { |k, v| puts "#{k}: #{v}" }
 http.finish  #the lines above return the response and print headers
 puts " "
# -----------------------------------------------------------------------------

puts "START GENERIC PORTAL CHECKS".bold.bg_gray.red
uri = URI(site)
hostFileName = options[:uri]
hostFile = File.open(hostFileName,"r") { |file|
  # begin login to determine HTTP or HTTPS
  while (folder = file.gets)
    http = Net::HTTP.new(uri.host,uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Get.new(File.join(uri.path, folder))
    response = http.request(request)
    if response.code == "200" #or response.code == "302"
      puts "#{File.join(uri.to_s,folder)} STATUS=#{response.code}".green + " PROTOCOL=#{uri.scheme}".red
    end
  end
}

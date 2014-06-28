#!/usr/bin/env ruby
# -----------------------------------------------------------------------------
# URL checker will perform OSINT using static URLs for known internet facing app
# -----------------------------------------------------------------------------
# RubyOSINT v1
# Thanks to @carnalOwnage for the idea and some code. Also Alex for the Ruby foo.
# -----------------------------------------------------------------------------
require 'uri'
require 'net/http'
require 'net/https'
require 'optparse'
# -----------------------------------------------------------------------------
class String
  def black;          "\033[30m#{self}\033[0m" end
  def red;            "\033[31m#{self}\033[0m" end
  def green;          "\033[32m#{self}\033[0m" end
  def brown;          "\033[33m#{self}\033[0m" end
  def blue;           "\033[34m#{self}\033[0m" end
  def magenta;        "\033[35m#{self}\033[0m" end
  def cyan;           "\033[36m#{self}\033[0m" end
  def gray;           "\033[37m#{self}\033[0m" end
  def bg_black;       "\033[40m#{self}\033[0m" end
  def bg_red;         "\033[41m#{self}\033[0m" end
  def bg_green;       "\033[42m#{self}\033[0m" end
  def bg_brown;       "\033[43m#{self}\033[0m" end
  def bg_blue;        "\033[44m#{self}\033[0m" end
  def bg_magenta;     "\033[45m#{self}\033[0m" end
  def bg_cyan;        "\033[46m#{self}\033[0m" end
  def bg_gray;        "\033[47m#{self}\033[0m" end
  def bold;           "\033[1m#{self}\033[22m" end
  def reverse_color;  "\033[7m#{self}\033[27m" end
end
# -----------------------------------------------------------------------------
options = {}
# -----------------------------------------------------------------------------
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

  options[:debug] = false
  opts.on('-d','--debug', 'Show debug information.') do
    options[:debug] = true
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
optparse.parse!

# -----------------------------------------------------------------------------
if options[:url].nil? or options[:uri].nil?
  puts optparse
  exit
end
# -----------------------------------------------------------------------------
if options[:debug]
  require 'pry'
  require 'yaml'
end
# -----------------------------------------------------------------------------
module OSINT
  class Target
    attr_reader :uri, :ssl

    def initialize(url)
      @uri = URI.parse(url)
      @ssl = { :use_ssl => (@uri.scheme == 'https') }
      if @ssl[:use_ssl]
        @ssl[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
      end      
    end

    def configure_ssl
      @ssl = nil
      @ssl = { :use_ssl => (@uri.scheme == 'https') }
      if @ssl[:use_ssl]
        @ssl[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
      end
    end      

    def to_s
      @uri.to_s
    end

    def full_uri(path)
      File.join(@uri.path, URI.encode(path))
    end

    def request(path, limit=5, method=:get)
      raise ArgumentError, 'HTTP Redirect Loop Detected' if limit == 0
      response = Net::HTTP.start(@uri.host, @uri.port, @ssl) do |http|
        http.send(method, path)
      end
      if response.nil?
        puts "Failure in response."
        exit 1
      end
      if [ "302", "301"].include? response.code
        new_path = URI.parse(response.header['location'])
        if !new_path.host.nil? && new_path.host != @uri.host
          @uri.host = new_path.host
        end
        if !new_path.scheme.nil? && new_path.scheme != @uri.scheme
          @uri.scheme = new_path.scheme
          configure_ssl
        end
        if !new_path.respond_to? :request_uri
          request(new_path.to_s, limit - 1)
        else
          request(new_path.request_uri, limit - 1)      
        end        
      else
        return response, path
      end
    end

    def search(path, method=:get)
      if block_given?
        if path.is_a? Array
          path.each do |p|
            yield request(full_uri(p), 5, method)
          end
        elsif path.is_a? String
          yield request(full_uri(path), 5, method)
        else
          yield nil
        end
      else
        return request(get(path), 5, method)
      end
    end
  end
end
# -----------------------------------------------------------------------------
site = OSINT::Target.new(options[:url])
list = File.readlines(options[:uri]).map{|l| l.strip! }
# -----------------------------------------------------------------------------
puts "THE TARGET DOMAIN IN SCOPE IS: ".bold.red +  "#{site}".green.bold
puts ""
# -----------------------------------------------------------------------------
puts "DUMPING WEBSERVER HEADERS: ".bold.red
puts ""
site.search("/", :head) do |response, path|
  response.header.each { |k, v| puts "#{k.to_s.green.bold}: #{v}" }
end
# -----------------------------------------------------------------------------
puts ""
puts "START PATH CHECKS".bold.red
puts ""
# -----------------------------------------------------------------------------
site.search(list) do |response, path|
  if options[:debug] == true
    puts "[ #{response.code.green} ] #{File.join(site.uri.to_s, path)}"
  else
    if response.respond_to? :code
      if [ "200" , "500" , "400" ].include? response.code
        puts "[ #{response.code.green} ] #{File.join(site.uri.to_s, path)}"
      end
    else
      abort "[!] Fatal: Response object did not respond to :code method."
    end        
  end
end 
# -----------------------------------------------------------------------------

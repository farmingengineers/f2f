#!/usr/bin/env ruby
#/ Usage: _script/extract-html.rb mail.txt
#/
#/ Writes the html part of the mail message to mail.html.

require 'bundler/setup'
require 'mail'
require 'shellwords'

def main(path)
  outpath = path + '.html'
  puts "#{path} -> #{outpath}"
  if File.exists?(outpath)
    puts "Error: #{outpath} exists"
  else
    File.write(outpath, Mail.read(path).html_part.body.decoded)
  end
end

if ARGV.empty?
  system "cat #{Shellwords.escape(__FILE__)} | grep ^#/ | cut -c4-"
  exit 1
else
  ARGV.each do |path|
    main(path)
  end
end

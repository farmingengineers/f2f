#!/usr/bin/env ruby
#/ Usage: _script/convert-newsletters.rb
#/
#/ Converts all newsletters in _raw/ to posts in _posts/

require 'bundler/setup'
require 'mail'
require 'nokogiri'

def main
  Dir['_raw/*'].each do |raw_path|
    output_path = "_posts/#{File.basename(raw_path, '.txt')}.html"
    puts "#{raw_path} -> #{output_path}"
    File.open output_path, 'w' do |f|
      convert raw_path, f
    end
  end
end

def convert(raw_path, out)
  mail = Mail.read(raw_path)
  html = Nokogiri::HTML(mail.html_part.body.decoded)
  write_front_matter(out, mail, html)
  write_content(out, mail, html)
end

def write_front_matter(out, mail, html)
  data = {}
  data['title'] = mail.subject
  data['category'] = 'newsletters'
  data['layout'] = 'newsletter'
  data['images'] = images = []
  sidebar_items = html.xpath('//*[@id="rootDiv"]/div[4]/table/tr/td/table/tr[2]/td/table/tr/td[1]/table/tr/td/table')
  spacers_found = 0
  sidebar_items.each do |e|
    if( (img = e.css('img').first) && (img['src'] =~ /spacer/) )
      spacers_found += 1
    end
    if e['id'] && e['id'].start_with?('content_LETTER.BLOCK')
      item = e#.css('p').first
      image = item && item.css('img').first
      caption = item && item.text.gsub(/\s+/, ' ').strip
      if spacers_found == 3 && item && image && caption
        images.push 'url' => image['src'], 'caption' => caption
      end
    end
  end
  out.puts YAML.dump(data)
  out.puts '---'
end

def write_content(out, mail, html)
  main = html.xpath('//*[@id="rootDiv"]/div[4]/table/tr/td/table/tr[2]/td/table/tr/td[2]/table/tr/td')
  res = Nokogiri::HTML::Builder.new do |h|
    h.div do
      main.css('table').each do |section|
        title_element = section.css('div[align=center]')
        title_element = section.css('div[style]') if title_element.empty?
        title = title_element.text.gsub(/\s+/, ' ').strip
        unless title.empty?
          h.h4 title
          title_element.remove
        end
        puts "title: " + title.inspect
        section.css('p').each do |p|
          text = p.text.gsub(/\s+/, ' ').strip
          if text =~ /[a-z]/
            h.p text
            puts text.inspect[0,100]
          end
        end
      end
    end
  end
  out.puts res.doc.root.children
end


main

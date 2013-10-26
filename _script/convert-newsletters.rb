#!/usr/bin/env ruby
#/ Usage: _script/convert-newsletters.rb
#/
#/ Converts all newsletters in _raw/ to posts in _posts/

require 'bundler/setup'
require 'mail'
require 'nokogiri'

def main(*files)
  files = Dir['_raw/*'] if files.empty?
  files.each do |raw_path|
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
      caption = item && get_clean_text(item)
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
    h.body do
      main.css('table').each do |section|
        write_section(h, section)
      end
    end
  end
  out.puts res.doc.root.children
end

def write_section(h, section)
  h.div :class => 'newsletter-section' do
    write_section_title(h, section)
    write_section_body(h, section)
  end
end

def write_section_title(h, section)
  title_elements = section.css('div[align=center]')
  title_elements = section.css('div[style]') if title_elements.empty?
  title_text = ''
  title_elements.each do |title_element|
    if title_element.css('img').empty?
      title = get_clean_text(title_element)
      unless title.empty?
        title_text << title
        title_element.remove
      end
    end
  end
  h.h4(title_text) if title_text =~ /[a-z]/i
end

def write_section_body(h, section)
  section.xpath('.//p|.//table').each do |p|
    if p.text =~ /[a-z]/
      h.p do
        write_stripped(h, p)
      end
    end
  end
end

def write_stripped(h, parent)
  parent.children.each do |node|
    if node.text?
      h.text(node.text)
    elsif node.name.downcase == 'a' && node['href']
      h.a 'href' => node['href'] do
        write_stripped(h, node)
      end
    elsif node.name.downcase == 'img' && node['src']
      h.div { h.img 'src' => node['src'] }
    else
      write_stripped(h, node)
    end
  end
end

def get_clean_text(element)
  element.text.gsub(/\s+/, ' ').strip
rescue ArgumentError
  s = element.text.dup
  s.force_encoding 'BINARY'
  s.gsub(/\s+/, ' ').strip
end


main(*ARGV)

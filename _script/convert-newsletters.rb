#!/usr/bin/env ruby
#/ Usage: _script/convert-newsletters.rb
#/
#/ Converts all newsletters in _raw/ to posts in _posts/

require 'bundler/setup'
require 'digest/md5'
require 'mail'
require 'nokogiri'
require 'net/http'

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
        images.push 'url' => make_image_local(image['src']), 'caption' => caption
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
      write_dat(h, main)
    end
  end
  out.puts res.doc.root.children
end

def write_dat(h, node)
  node.children.each do |child|
    if child.text?
      text = get_clean_text(child)
      h.text(text.empty? ? ' ' : text)
    elsif child.name == 'a' && child['href']
      h.a 'href' => get_real_location(child['href']) do
        write_dat(h, child)
      end
    elsif child.name == 'img' && child['src']
      h.div { h.img 'src' => make_image_local(child['src']) }
    elsif child.name == 'span' && child['style'] =~ /16pt/ && child.css('img').empty?
      h.h4 { h.text(get_clean_text(child)) }
    elsif child.name == 'p'
      h.p { write_dat(h, child) }
    else
      write_dat(h, child)
    end
  end
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
  ps = section.xpath('.//p|.//table')
  ps.each do |p|
    if pred = p.previous_element
      if pred.name == 'span' && pred.css('p').empty? && pred.text =~ /[a-z]/
        h.p do
          write_stripped(h, pred)
        end
      end
    end
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
      h.a 'href' => get_real_location(node['href']) do
        write_stripped(h, node)
      end
    elsif node.name.downcase == 'img' && node['src']
      h.div { h.img 'src' => make_image_local(node['src']) }
    else
      write_stripped(h, node)
    end
  end
end

Utf8Nbsp = Nokogiri::HTML('<span>&nbsp;</span>').css('span').text

def get_clean_text(element)
  s = element.text.dup
  begin
    s = s.gsub('&nbsp;', ' ')
    s = s.gsub(Utf8Nbsp, ' ') if s.encoding == Utf8Nbsp.encoding
    s = s.gsub(/\s+/, ' ')
  rescue ArgumentError
    original_encoding = s.encoding
    s.force_encoding 'BINARY'
    if s.encoding != original_encoding
      retry
    else
      raise
    end
  end
  s
rescue ArgumentError
  s = element.text.dup
  s.force_encoding 'BINARY'
  s.gsub(/\s+/, ' ').strip
end

def make_image_local(url)
  path = "images/newsletters/#{Digest::MD5.hexdigest(url)}#{File.extname(url)}"
  unless File.exists?(path)
    File.write(path, Net::HTTP.get(URI(url)))
  end
  '/' + path
rescue => e
  puts "Unable to create local image (#{e})"
  url
end

HrefCache = '_cc_hrefs.yml'

def get_real_location(url)
  cc_locations = (YAML.load_file(HrefCache) rescue nil)
  cc_locations = {} unless cc_locations.is_a?(Hash)
  cc_locations.fetch(url) do
    uri = URI(url)
    if uri.scheme == 'https' || uri.scheme == 'http'
      response = Net::HTTP.get_response(uri)
      if response.code.start_with?('3') && location = response['Location']
        cc_locations[url] = location
        File.write(HrefCache, YAML.dump(cc_locations))
        location
      else
        puts "Got #{response.code} from #{url}"
        url
      end
    else
      url
    end
  end
rescue => e
  puts "Unable to get real location for #{url} (#{e})"
  url
end


main(*ARGV)

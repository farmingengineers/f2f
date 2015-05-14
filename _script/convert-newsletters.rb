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
  converter = F2fConverter.new
  files = Dir['_raw/*'] if files.empty?
  files.each do |raw_path|
    mail = Mail.read(raw_path)
    converter.convert_to_post(mail, raw_path: raw_path)
  end
  converter.git_add
  system "git", "status"
end

class F2fConverter
  def convert_to_post(mail, raw_path: "")
    output_path = generate_output_path(raw_path, mail)
    puts "#{raw_path} -> #{output_path}"
    File.open output_path, 'w' do |f|
      convert mail, f
    end
  end

  def git_add
    system "git", "add", "-v", "_posts", "_cc_hrefs.yml", "images"
  end

  private

  def generate_output_path(raw_path, mail)
    date, name =
      case base = File.basename(raw_path, '.txt')
      when /^(\d\d\d\d-\d\d-\d\d)-(.+)/
        [$1, $2]
      else
        [mail.date.strftime("%Y-%m-%d"), mail.subject]
      end
    # Make spaces into dashes, make it lowercase, and remove everything else.
    fixed_name = name.downcase.tr(' ', '-').gsub(/[^a-z0-9-]+/, '').gsub(/-+/, '-')
    "_posts/#{date}-#{fixed_name}.txt"
  end

  def convert(mail, out)
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
    sidebar_items = html.xpath('//*[@id="rootDiv"]/div/table/tr/td/table/tr[2]/td/table/tr/td[1]/table/tr/td/table')
    sidebar_items.each do |e|
      img = e.css('img').first
      if e['id'] && e['id'].start_with?('content_LETTER.BLOCK') && (image = e.css('img').first) && image['src'] !~ /spacer/
        caption = get_clean_text(e).strip
        if caption.to_s =~ /[a-z]/i
          images.push 'url' => make_image_local(image['src']), 'caption' => caption
        end
      end
    end
    out.puts YAML.dump(data)
    out.puts '---'
  end

  def write_content(out, mail, html)
    main = html.xpath('//*[@id="rootDiv"]/div/table/tr/td/table/tr[2]/td/table/tr/td[2]')
    res = Nokogiri::HTML::Builder.new do |h|
      h.body do
        write_dat(h, main)
      end
    end
    out.puts res.doc.root.children
  end

  Nbsp = Nokogiri::HTML('&nbsp;').text.freeze
  Nbsp2 = Nbsp + Nbsp

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
        local_url = make_image_local(child['src'])
        h.div { h.img 'src' => local_url, 'class' => "img-#{File.basename(local_url).split('.')[0]}" }
      elsif child.name == 'span' && child['style'] =~ /16pt/ && child.css('img').empty? && child.text.length < 200
        h.h4 { h.text(get_clean_text(child)) }
      elsif child.name == 'p'
        h.p { write_dat(h, child) }
      elsif child.name == 'div' && child.text == Nbsp2
        h.div { h.text(child.text) }
      else
        write_dat(h, child)
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
end


if __FILE__ == $0
  main(*ARGV)
end

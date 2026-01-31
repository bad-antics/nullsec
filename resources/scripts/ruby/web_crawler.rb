#!/usr/bin/env ruby
# Simple web crawler for reconnaissance

require 'net/http'
require 'uri'
require 'nokogiri'

class WebCrawler
  def initialize(base_url, max_depth=2)
    @base_url = base_url
    @max_depth = max_depth
    @visited = Set.new
    @found_urls = []
  end
  
  def crawl(url=@base_url, depth=0)
    return if depth > @max_depth
    return if @visited.include?(url)
    
    @visited.add(url)
    puts "[*] Crawling: #{url}"
    
    begin
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        doc = Nokogiri::HTML(response.body)
        
        doc.css('a').each do |link|
          href = link['href']
          next unless href
          
          full_url = URI.join(url, href).to_s
          
          if full_url.start_with?(@base_url)
            @found_urls << full_url
            crawl(full_url, depth + 1)
          end
        end
      end
      
    rescue => e
      puts "[-] Error crawling #{url}: #{e.message}"
    end
  end
  
  def results
    @found_urls.uniq
  end
end

if __FILE__ == $0
  if ARGV.length < 1
    puts "Usage: web_crawler.rb <url>"
    exit 1
  end
  
  crawler = WebCrawler.new(ARGV[0])
  crawler.crawl
  
  puts "\n[+] Found #{crawler.results.length} URLs"
  crawler.results.each { |url| puts "  #{url}" }
end

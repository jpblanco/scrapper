require 'nokogiri'

ANDROID_HOST="https://market.android.com"

class App
  attr_accessor :name
  attr_accessor :url
  attr_accessor :price
  attr_accessor :downloads_min
  attr_accessor :downloads_max
  attr_accessor :downloads_avg
  attr_accessor :size
end

def obtain_app_details(app)
  url = app.url
  doc = Nokogiri::HTML(%x(curl -s -X GET #{url}))

  app.price = doc.css("dl.doc-metadata-list > dd:last-child").first.content
  downloads = doc.css("dl.doc-metadata-list > dd")[5].content.split(" - ")
  app.downloads_min = downloads[0].gsub(",","")
  app.downloads_max = downloads[1].gsub(",","")
  app.downloads_avg = (app.downloads_min.to_i + app.downloads_max.to_i) / 2
  app.size = doc.css("dl.doc-metadata-list > dd")[6].content
end

def search(query, pages, options ={})
  apps = []
  prev_time = Time.now
  default_options = { :filter => "no_filter", :sort => "relevance"}
  default_options.merge(options)

  real_filters = { :free => "price=1",
                   :paid => "price=2",
                   :no_filter => "price=0" }

  real_sort = { :relevance => "sort=1",
                :popularity => "sort=0" }

  puts "Haciendo busqueda"
  puts ""

  (1..pages).each do |page|
    url ="#{ANDROID_HOST}/search?q=#{query}&c=apps&#{real_filters[default_options[:filter].to_sym]}&#{real_sort[default_options[:sort].to_sym]}&start=#{(page-1)*12}&num=12"

    #BUG: it seems I only get the same html for the different pages, no idea why.
    doc = Nokogiri::HTML(%x(curl -s -X GET #{url}))

    no_results = !(doc.css(".no-results-section").empty?)

    if no_results & (page == 1)
      puts "No hay resultados para #{query}."
      exit
    end

    print "Pagina #{page}   "

    print "(#{Time.now-prev_time} s)"
    puts ""

    doc.css('div.details a.title').each do |link|
      unless no_results
        app = App.new
        app.name = link["title"]
        app.url = ANDROID_HOST + link["href"]
        apps << app
      end
    end
  end
  apps
end

#usage: ruby scrapper.rb query --filter [free|paid] --sort [relevance|popularity]

query = ARGV.first

if query.nil?
  puts "Lo estas haciendo mal!"
  puts "Sintaxis: ruby scrapper.rb query --filter [free|paid] --sort [relevance|popularity]"
else
  filter = nil
  sort = nil
  pages = 5
  start_time = Time.now

  filter = ARGV[(ARGV.index "--filter") + 1]  unless (ARGV.index "--filter").nil?
  sort = ARGV[(ARGV.index "--sort") + 1]  unless (ARGV.index "--sort").nil?
  pages = ARGV[(ARGV.index "--pages") + 1].to_i  unless (ARGV.index "--pages").nil?

  apps = search(query, pages, {:filter => filter, :sort => sort})

  puts ""
  puts "Obteniendo datos de las aplicaciones."
  puts ""

  apps.each do |app|
    print "#{app.name}   "
    prev_time = Time.now
    obtain_app_details app
    print "(#{Time.now-prev_time} s)"
    puts ""
  end

  open("#{query}-apps.csv", "a") { |f|
    f.puts "Nombre,Url,Precio,DwnMin,DwnMax,DwnAvg,Espacio"

    apps.each do |app|
      f.puts "#{app.name},#{app.url},#{app.price},#{app.downloads_min},#{app.downloads_max},#{app.downloads_avg},#{app.size}"
    end
  }

  puts ""
  puts "Finalizado en #{Time.now - start_time} s"
end



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
  print "#{app.name}   "
  url = app.url
  prev_time = Time.now
  doc = Nokogiri::HTML(%x(curl -s -X GET #{url} > "access.log"))

  app.price = doc.css("dl.doc-metadata-list > dd:last-child").first.content
  downloads = doc.css("dl.doc-metadata-list > dd")[5].content.split(" - ")
  app.downloads_min = downloads[0].gsub(",","")
  app.downloads_max = downloads[1].gsub(",","")
  app.downloads_avg = (app.downloads_min.to_i + app.downloads_max.to_i) / 2
  app.size = doc.css("dl.doc-metadata-list > dd")[6].content

  print "(#{Time.now-prev_time} s)"
  puts ""
end

def search(query, options ={})
  page = 1
  prev_time = Time.now
  default_options = { :filter => "no_filter", :sort => "relevance" }
  default_options.merge(options)

  real_filters = { :free => "price=1",
                   :paid => "price=2",
                   :no_filter => "price=0" }

  real_sort = { :relevance => "sort=1",
                :popularity => "sort=0" }

  url ="https://market.android.com/search?q=#{query}&c=apps&#{real_filters[default_options[:filter].to_sym]}&#{real_sort[default_options[:sort].to_sym]}"

  puts "Haciendo busqueda"
  print "Pagina #{page}   "
  doc = Nokogiri::HTML(%x(curl -s -X GET #{url} > "access.log"))
  print "(#{Time.now-prev_time} s)"
  puts ""

  apps = []
  doc.css('div.details a.title').each do |link|
    app = App.new
    app.name = link["title"]
    app.url = ANDROID_HOST + link["href"]
    apps << app
  end

  apps
end

#usage: ruby scrapper.rb query --filter [free|paid] --sort [relevance|popularity]

query = ARGV.first

filter = nil
sort = nil

filter = ARGV[(ARGV.index "--filter") + 1]  unless (ARGV.index "--filter").nil?
sort = ARGV[(ARGV.index "--sort") + 1]  unless (ARGV.index "--sort").nil?

apps = search(query, {:filter => filter, :sort => sort})



open("#{query}-apps.csv", "a") { |f|
  f.puts "Nombre,Url,Precio,DwnMin,DwnMax,DwnAvg,Espacio"

  apps.each do |app|
    f.puts "#{app.name},#{app.url},#{app.price},#{app.downloads_min},#{app.downloads_max},#{app.downloads_avg},#{app.size}"
  end
}

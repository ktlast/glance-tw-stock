require "http/client"
require "json"
require "csv"
require "option_parser"


# watch and download remote table periodically.
class RemoteDataCache
  def initialize(meta_cache_path : String)
    @meta_cache_path = meta_cache_path
    @meta_hash = Hash(String, Hash(String, Int64 | String)).new
    
    if File.exists?(@meta_cache_path)
      @meta_hash = Hash(String, Hash(String, Int64 | String)).from_json(File.read(meta_cache_path))
    else
      File.write(@meta_cache_path, "{}")
    end
  end

  def update_meta(meta_key, url=nil, file_suffix="txt")
    if url == nil
      puts "ERROR: input [url] is empty, please update with valid url. (meta file: [#{@meta_cache_path}])"
      exit
    end

    # if @meta_hash.has_key?(meta_key)
    #   url = @meta_hash[meta_key]["url"]
    # else
      
    # end
    @meta_hash[meta_key] = {
      "timestamp_meta" => Time.utc.to_unix,
      "timestamp_data" => Time.unix(0).to_unix,
      "url" => url,
      "file_path" => "./.meta.#{meta_key}.#{file_suffix}"
    }
    # File.write(@meta_hash[meta_key]["file_path"].to_s, "")
    File.write(@meta_cache_path, @meta_hash.to_json)
  end

  def is_data_expired(meta_key, input_seconds)
    return Time.utc.to_unix - @meta_hash[meta_key]["timestamp_data"].to_i > input_seconds
  end

  def download_data(meta_key)
    response = HTTP::Client.get @meta_hash[meta_key]["url"].to_s
    if response.status_code.to_s != "200"
      puts "HTTP ERROR: got status code: [#{response.status_code}] (CSV URL: [#{@meta_hash[meta_key]["url"]}])"
      return
    end
    File.write(@meta_hash[meta_key]["file_path"].to_s, response.body)
    @meta_hash[meta_key]["timestamp_data"] = Time.utc.to_unix
  end

  def get_meta(meta_key, meta_type)
    if ! @meta_hash.has_key?(meta_key)
      puts "ERROR: [@meta_hash] does not have key: [#{meta_key}]"
      return ""
    end
    return @meta_hash[meta_key][meta_type].to_s
  end

  def get_data(meta_key, refresh_only=false)
    if ! @meta_hash.has_key?(meta_key)
      puts "ERROR: [@meta_hash] does not have key: [#{meta_key}]"
      return ""
    end
    if ! @meta_hash[meta_key]["url"].to_s.empty?
      if self.is_data_expired(meta_key, 86400) || ! File.exists?(@meta_hash[meta_key]["file_path"].to_s) || 
        self.download_data(meta_key)
      end
    end
    if ! refresh_only
      return File.read(@meta_hash[meta_key]["file_path"].to_s)
    end
    return ""

  end
end 



class Portfolio
  # property exchange_table : Hash(String, String)
  # property positions : Hash(String, Hash(String, String | Int32 | Float32))
  setter update_interval : Int32 = 15
  @data_source = RemoteDataCache.new ".portfolio.meta.json"

  def initialize()
    @exchange_table = Hash(String, String).new
    @positions = Hash(String, Hash(String, Int32 | Float32)).new
    @code_params = Set(String).new
    @total_pl = 0
    # @positions = Hash(String, Int32 | Hash(String, String)).new

    @data_source.update_meta("stock_exchange_table", "https://raw.githubusercontent.com/ktlast/market-envs/master/stock-code-exchange.tw.csv", file_suffix: "csv")
    @data_source.update_meta("portfolio", "", file_suffix: "csv")
    
    CSV.each_row(@data_source.get_data("stock_exchange_table").to_s) do |row|
      if row.size == 0
        next
      end
      @exchange_table[row[0]] = row[1]
    end
  end


  def update_position()
    @code_params = Set(String).new
    CSV.each_row(@data_source.get_data("portfolio")) do |row|
      if row.size == 0
        next
      end
      stock_code = row[0]
      shares = row[1].to_i
      at_cost = row[2].to_f32
      
      # puts "#{@exchange_table[stock_code]}_#{stock_code}.tw"
      @code_params.add("#{@exchange_table[stock_code]}_#{stock_code}.tw")
      @positions[stock_code] = {
        "shares" => shares,
        "at_cost" => at_cost,
        "bid" => 0,
        "ask" => 0,
        "PL" => 0,
      }
    end
  end

  # def remove_position(stock_code : String)
  #   @code_params.delete("#{@exchange_table[stock_code]}_#{stock_code}.tw")
  #   @positions.delete(stock_code)
  # end

  def update_quote()
    @total_pl = 0
    response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=#{@code_params.join("|")}&json=1&delay=0"
    result_arr = JSON.parse(response.body)["msgArray"].as_a
    result_arr.each do |symbol|
      #  puts  symbol["b"].to_s.split("_")[0].to_f32
      #  puts @positions[stock_code]["bid"] = symbol["b"]
      stock_code = symbol["c"]
      bid_price = symbol["b"].to_s.split("_")[0].to_f32.round(2)
      ask_price = symbol["a"].to_s.split("_")[0].to_f32.round(2)
      @positions[stock_code]["bid"] = bid_price
      @positions[stock_code]["ask"] = ask_price
      raw_pl = ((bid_price - @positions[stock_code]["at_cost"]) * @positions[stock_code]["shares"])
      @positions[stock_code]["PL"] = raw_pl.floor.to_i
      @total_pl += raw_pl.floor.to_i
    end
  end

  def print_out()
    puts "╭#{"─" * 70}╮"
    #╭───────────────────────────────────────────────────╮
# ┊ Node  ┊ NodeType ┊ Addresses              ┊ State  ┊
# ╞┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄╡
# ┊ nodeA ┊ COMBINED ┊ 10.50.2.4:3366 (PLAIN) ┊ Online ┊
# ┊ nodeB ┊ SATELLITE┊ 10.50.2.5:3366 (PLAIN) ┊ Online ┊
# ┊ nodeC ┊ SATELLITE┊ 10.50.2.6:3366 (PLAIN) ┊ Online ┊
# ╰────────────────────────────────────────────────────╯
    # Title
    puts "┊ #{"Code".ljust(9)}#{"# Shares".rjust(10)}#{"@ Cost".rjust(13)}#{"*Bid".rjust(11)}#{"Ask".rjust(11)}#{"$ P/L".rjust(14)} ┊"
    # puts "-"*68
    puts "╞#{"┄" * 70}╡"
    # entries
    @positions.keys.each do |stock_code|
      entry_line = "┊ #{stock_code.ljust(9)}\
        #{@positions[stock_code]["shares"].format(",").rjust(10)}\
        #{@positions[stock_code]["at_cost"].to_s.rjust(13)}\
        #{@positions[stock_code]["bid"].to_s.rjust(11)}\
        #{@positions[stock_code]["ask"].to_s.rjust(11)}\
        #{@positions[stock_code]["PL"].format(",").rjust(14)} ┊"
      puts entry_line
    end
    puts "╞#{"=" * 70}╡"
    puts "┊ TOTAL: #{@total_pl.format(",").to_s.rjust(61)} ┊"
    puts "╰#{"─" * 70}╯"
  end

  def watch_forever()
    while true
      puts "\33c\e[3J"
      self.update_position
      self.update_quote
      self.print_out
      sleep @update_interval
    end
  end
end


# Portfolio init
# data_source = RemoteDataCache.new "deleteme.meta.json"


# p data_source.get_meta("stock_exchange_table", "file_path").to_s

# data_source.get_data("stock_exchange_table", refresh_only=true)
portfolio_data_source = RemoteDataCache.new ".portfolio.meta.json"

my_portfolio = Portfolio.new
# my_portfolio = Portfolio.new data_source.get_meta("stock_exchange_table", "file_path").to_s


# main argument parser
option_parser = OptionParser.parse do |parser|
  parser.banner = "Welcome to glance price on TW Stock !\n"

  parser.on "-v", "--version", "Show version" do
    puts "version: v0.0.1"
    exit
  end

  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end

  parser.on "-a POSITION", "Add a Position entry. format: <code>,<shares>,<at_cost>" do |position|
    content = portfolio_data_source.get_data("portfolio").to_s
    input_pos = position.split(",")
    if input_pos.size != 3
      position = "#{input_pos[0]},0,0"
    end
    File.write(portfolio_data_source.get_meta("portfolio", "file_path").to_s, (content.gsub(/#{input_pos[0]},[\.0-9,]+\n?/, "") + "\n#{position}").gsub(/\n\n+/, "\n"))
    exit
  end

  parser.on "-d STOCK_CODE", "Delete a Position entry. format: <code>" do |stock_code|
    content = portfolio_data_source.get_data("portfolio").to_s
    File.write(portfolio_data_source.get_meta("portfolio", "file_path").to_s, content.gsub(/#{stock_code}[\.0-9,]*\n?/, "").gsub(/\n\n+/, "\n"))
    exit
  end

  parser.on "-l", "List Positions." do
    puts File.read(portfolio_data_source.get_meta("portfolio", "file_path").to_s)
    exit
  end

  parser.on "-i INTERVAL", "Set interval for updating quotes." do |interval|
    my_portfolio.update_interval = interval.to_i
  end
  
  parser.on "start", "Start update quotes forever based on portfolio." do
    my_portfolio.watch_forever
  end

  parser.missing_option do |option_flag|
    STDERR.puts "ERROR: #{option_flag} is missing something."
    STDERR.puts ""
    STDERR.puts parser
    exit(1)
  end

  parser.invalid_option do |option_flag|
    STDERR.puts "ERROR: #{option_flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end



# CSV.each_row(data_source.get_data("portfolio")) do |row|
#   if row.size == 0 || row[0].strip.starts_with?('#')
#     next
#   end
 
# end

# my_portfolio.watch_forever






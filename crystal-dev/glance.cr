require "http/client"
require "json"
require "csv"
require "option_parser"


class Portfolio
  # property exchange_table : Hash(String, String)
  # property positions : Hash(String, Hash(String, String | Int32 | Float32))
  setter update_interval : Int32 = 15 

  def initialize()
    @exchange_table = Hash(String, String).new
    @positions = Hash(String, Hash(String, Int32 | Float32)).new
    @code_params = Set(String).new
    @total_pl = 0
    # @positions = Hash(String, Int32 | Hash(String, String)).new
    
    CSV.each_row(File.read("../.exchange_table.csv")) do |row|
      if row.size == 0
        next
      end
      @exchange_table[row[0]] = row[1]
    end
  end


  def add_position(stock_code : String, shares : Int32, at_cost : Float32)
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

  def remove_position(stock_code : String)
    @code_params.delete("#{@exchange_table[stock_code]}_#{stock_code}.tw")
    @positions.delete(stock_code)
  end

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
    # Title
    puts "#{"Code".ljust(9)}#{"# Shares".rjust(10)}#{"@ Cost".rjust(13)}#{"*Bid".rjust(11)}#{"Ask".rjust(11)}#{"$ P/L".rjust(14)}"
    puts "-"*68
    # entries
    @positions.keys.each do |stock_code|
      entry_line = "#{stock_code.ljust(9)}\
        #{@positions[stock_code]["shares"].format(",").rjust(10)}\
        #{@positions[stock_code]["at_cost"].to_s.rjust(13)}\
        #{@positions[stock_code]["bid"].to_s.rjust(11)}\
        #{@positions[stock_code]["ask"].to_s.rjust(11)}\
        #{@positions[stock_code]["PL"].format(",").rjust(14)}"
      puts entry_line
    end
    puts "="*68
    puts @total_pl.format(",").to_s.rjust(68)
  end

  def start()
    while true
      puts "\33c\e[3J"
      self.update_quote
      self.print_out
      sleep @update_interval
    end
  end
end


# Portfolio init
my_portfolio = Portfolio.new
portfolio_csv_path = "../portfolio.csv"


# main argument parser
option_parser = OptionParser.parse do |parser|
  parser.banner = "Welcome to glance price on TW Stock !"

  parser.on "-v", "--version", "Show version" do
    puts "version: v0.0.1"
    exit
  end
  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end
  parser.on "-i INTERVAL", "Set interval for updating quotes." do |interval|
    my_portfolio.update_interval = interval.to_i
  end
  parser.on "-f PORTFOLIO_CSV", "Read PORTFOLIO_CSV to collect your Portfolio." do |portfolio_csv|
    portfolio_csv_path = portfolio_csv
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


if ! File.exists?(portfolio_csv_path)
  exit
end  

CSV.each_row(File.read(portfolio_csv_path)) do |row|
  if row.size == 0 || row[0].strip.starts_with?('#')
    next
  end
  my_portfolio.add_position(row[0], row[1].to_i, row[2].to_f32)
end


my_portfolio.start




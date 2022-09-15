require "http/client"
require "json"

response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_9933.tw|otc_6248.tw&json=1&delay=0"
response.status_code      # => 200
result_arr = JSON.parse(response.body)["msgArray"].as_a

# result_arr.each do |x|
#   puts x["c"] 
#   puts x["b"] 
#   puts x["a"] 
# end

class Portfolio
  # property exchange_table : Hash(String, String)
  # property positions : Hash(String, Hash(String, String | Int32 | Float32))

  def initialize()
    @exchange_table = Hash(String, String).new
    @positions = Hash(String, Hash(String, Int32 | Float32)).new
    @code_params = Set(String).new
    # @positions = Hash(String, Hash(String, String)).new

    File.read("../.exchange_table.csv").each_line do |line|
      entry = line.split(",")
      @exchange_table[entry[0]] = entry[1]
    end
  end


  def add_position(stock_code : String, shares : Int32, at_cost : Float32)
    puts stock_code
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
    response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=#{@code_params.join("|")}&json=1&delay=0"
    result_arr = JSON.parse(response.body)["msgArray"].as_a
    result_arr.each do |symbol|
      #  puts  symbol["b"].to_s.split("_")[0].to_f32
      #  puts @positions[stock_code]["bid"] = symbol["b"]
      stock_code = symbol["c"]
      bid_price = symbol["b"].to_s.split("_")[0].to_f32
      ask_price = symbol["a"].to_s.split("_")[0].to_f32
      @positions[stock_code]["bid"] = bid_price
      @positions[stock_code]["ask"] = ask_price
      @positions[stock_code]["PL"] = (bid_price - @positions[stock_code]["at_cost"]) * @positions[stock_code]["shares"]
      # @positions[stock_code]["PL"]
    end
  end

  def print_out()
    puts "#{"Code".ljust(8)}#{"# shares".rjust(9)}#{"@ Cost".rjust(10)}#{"Bid".rjust(9)}#{"Ask".rjust(8)}#{"P/L".rjust(8)}"
    @positions.keys.each do |stock_code|
      puts "#{stock_code.ljust(8)}#{@positions[stock_code]["shares"].to_s.rjust(9)}#{@positions[stock_code]["at_cost"].to_s.rjust(9)}#{@positions[stock_code]["bid"].to_s.rjust(8)}#{@positions[stock_code]["ask"].to_s.rjust(8)}#{@positions[stock_code]["PL"].to_s.rjust(10)}"
    end
  end
end

pp = Portfolio.new
# puts pp.@exchange_table
pp.add_position("9933", 4000, 46.1)
pp.add_position("6248", 10000, 20.95)
pp.update_quote
puts pp.@positions
pp.print_out

# class Quote
#   property quote_hash : Hash(String, Hash(String, String | Float32 | Int32))
#   @init_stock_code_array : Array(String)
  
#   def initialize(init_stock_code_array)
#     @init_stock_code_array = init_stock_code_array
#     @quote_hash = Hash(String, Hash(String, String | Float32 | Int32)).new
#     @exchange_hash = Hash(String, String).new
    
#     File.read("../.exchange_table.csv").each_line do |line|
#       entry = line.split(",")
#       @exchange_hash[entry[0]] = entry[1]
#     end
#   end

#   def _form_param()
#     param = ""
#     @init_stock_code_array.size.times { |x|
#       puts @init_stock_code_array[x]
#     }
#   end 

#   def update_price()
    

#   end  
# end


# class Position
#   property stock_code : String
#   property shares : Int32
#   property at_cost : Float32
#   property quote_hash : Hash(String, Hash(String, String | Float32 | Int32))

#   def initialize(stock_code : String)
#     @stock_code = stock_code
#     @shares = 0
#     @at_cost = 0.0
#     @exchange_hash = Hash(String, String).new
#     File.read("../.exchange_table.csv").each_line do |line|
#       entry = line.split(",")
#       @exchange_hash[entry[0]] = entry[1]
#     end
#   end

#   def _form_param()
#     param = ""
#     @init_stock_code_array.each { |x|
#       puts x
#     }
#   end 
  

# end


# class Portfolio
#   # property positions : Hash(String, Position)
#   @positions : Hash(String, Position)
  
#   def initialize()
#     @positions = Hash(String, Position).new
#   end

#   def add_position(position : Position)
#     @positions[position.stock_code] = position
#   end

#   def update_quote()
#     puts ""
#   end

#   def go
#     puts "Code  #Shares   @cost"
#     puts "#{@positions}"
#   end
# end

# qq = Quote.new ["9933", "2330"]
# qq.update_price
# puts qq.@exchange_hash

# my_port = Portfolio.new
# pos_9933 = Position.new "9933"
# pos_9933.shares = 1000
# pos_9933.at_cost = 46.1
# my_port.add_position(pos_9933)
# my_port.go





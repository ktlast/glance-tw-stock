require "http/client"
require "json"

response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_9933.tw|otc_6248.tw&json=1&delay=0"
response.status_code      # => 200
result_arr = JSON.parse(response.body)["msgArray"]

p! result_arr.size

result_arr.size.times { |x| 
  puts result_arr[x]["a"] 
}


class Portfolio
  def initialize(stock_code : String, shares : Int32)
    @stock_code = stock_code
    @shares = shares
  end

  def go
    puts "Code  Shares"
    puts "#{@stock_code} #{@shares}"
  end
end




# glance-tw-stock
假如你需要在上班時偷看一下報價

---
### Target Audience
- 工程師：上班會需要用 command line 
- 各行職員： 會需要用到 google 表格 (google sheet)

但是
- 每個人上班使用的作業系統不同 (Windows, OSX, Ubuntu .. )
- 每家行號的網路環境也不盡相同，有些可以上網、有些有部分限制


---

### A) 安裝
- 直接去 release 下載對應系統的執行檔。

---

### B) 說明 - 新增標的

1. 用 `add` 指令新增標的，標的格式為 `<股票代碼>,<股數>,<平均成本>`
2. 輸入**股數**，而非張數；並用底線隔開
3. 可以只輸入四碼代碼，代表並未持有、只想看報價；後面的股數與成本會自動設成 `0`

---

### C) Road Map
- 預計會提供指令版與網頁版 (JS)，目前先暫以指令版著手開發。

---

### D) Example - CLI

```
# 新增標的
./glance add 2330,10000,500
./glance add 2412,5000,kv125
./glance add 2498


# 如果要移除標的
./glance delete 2412


# 查看目前有哪些標的
./glance list


# 開始抓報價
./glance start


# 修改更新週期 (秒)
./glance -i 10 start
```
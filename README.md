# glance-tw-stock
假如你需要在上班時偷看一下報價

_

### A) 開發與環境說明
- 預計會提供指令版 (zsh / bash) 與網頁版 (JS)，目前先暫以指令版著手開發。
- bash 盡量使用 bash 4.0 以上版本，但指令都有盡量寫成通用的方式
- 能用 zsh 就用 zsh，主要開發環境是 OSX - zsh

---

### B) 前置檢查
- 需要有以下指令存在：

```
curl
jq
xargs
cut
python
```

---

### C) 說明 - 新增標的

1. 用 `add` 指令新增標的，標的格式為 `<股票代碼>_<股數>_<平均成本>`
2. 輸入**股數**，而非張數；並用底線隔開
3. 可以只輸入四碼代碼，代表並未持有、只想看報價；後面的股數與成本會自動設成 `0`

---

### D) Example

```
# 新增標的
./glance-standalone.sh add 2330_10000_500
./glance-standalone.sh add 2412_5000_125
./glance-standalone.sh add 2498


# 如果要移除標的
./glance-standalone.sh delete 2412


# 查看目前有哪些標的
./glance-standalone.sh list


# 開始抓報價
./glance-standalone.sh start


# 修改更新週期 (秒)
./glance-standalone.sh -i 10 start
```
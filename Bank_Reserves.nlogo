;; グローバル変数の定義
;;   主に、プロットへの表示に利用される。
globals [
  bank-loans                            ;; turtles の loans の合計
  bank-reserves                         ;; 銀行が保有している資金のうち、貸出に充てられない金額
  bank-deposits                         ;; turtles の savings の合計
  bank-to-loan                          ;; 銀行が保有している資金のうち、貸出に充てることができる額（余裕資金）
  bank-interest                         ;; 銀行が保有している資金のうち、利子で設けた利益
  bank-interest-loans                   ;; 追加:
  bank-profit                           ;; 追加
  x-max                                 ;; プロット("Money & Loans", "Savings & Wallets", "Income Dist")の表示のX軸の最大値 (初期値 300, プロットの式:set-plot-x-range 0 x-max)
  y-max                                 ;; プロット("Money & Loans", "Savings & Wallets")の表示のY軸の最大値 (初期値: 2 * money-total, プロットの式: set-plot-y-range -50 y-max)
  rich                                  ;; プロット("Income Dist")のrichの数 (プロットの式: plot rich)
  poor                                  ;; プロット("Income Dist")のpoorの数 (プロットの式: plot poor)
  middle-class                          ;; プロット("Income Dist")のmiddle-classの数(プロットの式: plot middle-class)
  rich-threshold                        ;; richの閾値。initialize-variables関数で10に設定される。また、setup-turtlesでwalletの初期値を決める)
]

;; turtleの変数
;;   turtleが持つ特性を表現するために利用される。以下、turtleの"属性"と呼称する。
turtles-own [
  savings                               ;; turtle の saving 属性
  loans                                 ;; turtle の loans 属性
  interest-loans                        ;; turtle の loansのうち利子分
  wallet                                ;; turtle の wallet 属性
  temp-loan                             ;; balance-books関数等で使用する属性。temp-loan = amount available to borrow
  temp-amount
  wealth                                ;; savings - loansの値を持つ属性。プロット("Wealth Distribution Histogram")でヒストグラムを作るのに利用される。
  customer                              ;; do-business関数で利用する属性。turtle自身の現在地に他のturtleがいるかどうかを表わす(one-of other turtles-here)。
]

;; Setup関数
;;   Setupボタンを押したときに呼ばれる初期化のための関数。
to setup
  clear-all                             ;; すべてを削除する
  initialize-variables                  ;; プロットに関するグローバル変数( rich, middle-class , poor, rich-threshold)の初期化
  ask patches [set pcolor black]        ;; パッチ(背景)を黒にする
  set-default-shape turtles "person"    ;; turtleの形を"人"にする
  create-turtles people [setup-turtles] ;; スライダーのpeopleグローバル変数の数分、setup-turtles関数で初期化したturtleを作成する。
  setup-bank                            ;; bankに関する変数(bank-loans, bank-reserves, bank-deposits, bank-to-loan)の初期化
  set x-max 300                         ;; プロットのX軸のx-maxグローバル変数の初期値を設定する
  set y-max 2 * money-total             ;; プロットのY軸のy-maxグローバル変数の初期値を設定する ( money-total の 2倍に設定する )
  reset-ticks                           ;; tick をリセットする
end

;; turtleに関する変数(属性)の初期化の関数
to setup-turtles  ;; turtle procedure   ;; あるturtleの処理
  set color blue                        ;; turtleを青にする
  setxy random-xcor random-ycor         ;; turtleをWorld上にランダムに配置する
  set wallet (random rich-threshold) + 1 ;;limit money to threshold ;; walletを1 ～ 10(rich-threshold)までの間で初期化する
  set savings 0                         ;; savings 属性の初期化
  set loans 0                           ;; loans 属性の初期化
  set interest-loans 0
  set wealth 0                          ;; wealth 属性の初期化
  set customer -1                       ;; customer 属性の初期化 (-1: 他のturtleが同じ場所にはいない)
end

;; bankに関する変数の初期化の関数
to setup-bank ;;initialize bank
  set bank-loans 0                      ;; bank-loansグローバル変数の初期化
  set bank-reserves 0                   ;; bank-reservesグローバル変数の初期化
  set bank-deposits 0                   ;; bank-depositsグローバル変数の初期化
  set bank-to-loan 0                    ;; bank-to-loanグローバル変数の初期化
  set bank-interest-loans 0             ;; 追加
  set bank-profit 0                     ;; 追加
end

;; プロットに関する変数の初期化の関数
to initialize-variables
  set rich 0                            ;; richグローバル変数の初期化
  set middle-class 0                    ;; middle-classグローバル変数の初期化
  set poor 0                            ;; poorグローバル変数の初期化
  set rich-threshold 10                 ;; rich-thresholdグローバル変数の初期化
end

;; turtleの色をsavings, loansの値に応じて変更する関数
to get-shape  ;;turtle procedure        ;; あるturtleの処理
  if (savings > 10)  [set color green]  ;; もし、savingsが10以上であるならば、turtleの色を緑にする
  if ((loans + interest-loans) > 10) [set color red]       ;; もし、loansが10以上であるならば、turtleの色を赤にする
  set wealth (savings - (loans + interest-loans))          ;; wealth変数
end

;; go ボタンを押したときに呼ばれるNetlogのプログラム進行のための関数
;;   tick関数によりシミュレーションが1つずつ進行する。シミュレーションの進んだ数をticksで取得きる。(以下ticks数と呼ぶ)
;;   ticks数を3で割った余りをチェックすることで、以下の３つのターンに分けてシミュレーションは進行する。
;;     余り 0 : do-bussiness関数を呼んで、turtleのビジネスを行う
;;     余り 1 : balance-book関数とget-shape関数を呼んで、turtleのお金の計算と色を変える
;;     余り 2(上記以外) : bank-balance-sheet関数を呼んで、savingsやloanの総額等を計算する
;;
to go
  ;;tabulates each distinct class population
  set rich (count turtles with [savings > rich-threshold]) ;; turtleのsavingsがrich-thresholdを超えるturtleの数をカウントしrichグローバル変数に入れる
  set poor (count turtles with [(loans + interest-loans) > 10])               ;; turtleのloansが10を超えるturtleの数をカウントしpoorグローバル変数に入れる
  set middle-class (count turtles - (rich + poor))         ;; turtleの総数 - (richとpoorの合計)をmiddle-classグローバル変数に入れる
  ask turtles [                                            ;; あるturtleを順番に取り出し、各変数に変更を加える。シミュレーション進行を司る処理。
    ifelse ticks mod 4 = 0                                ;; もし、ticks数を3で割り、余りが0かどうかをチェックし...(1)
      [do-business] ;;first cycle, "do business"           ;; (1)が真である場合、do-business関数を実行する
      [ifelse ticks mod 4 = 1  ;;second cycle, "balance books" and "get shape" ;; (1)が偽である場合、ticks数を3で割り、余りが1であるかチェックし...(2)
         [balance-books                                    ;; (2)が真である場合、balance-books関数を実行する
          get-shape]                                       ;; (2)が真である場合、get-shape関数を実行する
         [ifelse ticks mod 4 = 2                           ;; 追加: 4回に１回(月末)に利子を増やすための分岐..(101)
           [bank-balance-sheet] ;;third cycle, "bank balance sheet" ;; 上記以外(ticks数を3で割り余りが2である場合、bank-balance-sheet関数を実行する
           [if ticks mod 5 = 0
             [interest_to_loans]                             ;; interest_to_loans関数(スライダーのinterest変数の率だけローンを増やす)を実行する
           ]
        ]                                                  ;; (101)の範囲の終了
      ]                                                    ;; (2)の範囲の終了
      ;;print "wallet"
      ;;show wallet
    ]                                                      ;; (1)の範囲の終了

  tick                                                     ;; tickでシミュレーションを1つ進める
end

;; turtleのビジネスの関数
to do-business  ;;turtle procedure      ;; あるturtleの処理
  rt random-float 360                   ;; turtleの向きを変える(0～360の範囲で浮動所数点をランダムに決める)
  fd 1                                  ;; turtleが1つ前に進む

  if ((savings > 0) or (wallet > 0) or (bank-to-loan > 0))  ;; もし、savings、wallet、bank-to-loanのいずれかが0より大きいかチェックし...(3)
    [set customer one-of other turtles-here  ;; (3)が真である場合、turtleの現在地に他のturtleの１つをcustomerに入れる(いない場合はnobodyになる)
     if customer != nobody              ;; もし、customerがnobodyと等しくないかチェックし...(4)
     [if (random 2) = 0                 ;; 50% chance of trading with customer ;; もし、(4)が真である場合、ランダムに0～2よりも小さい値({0,1}) を生成し、0であるかチェックし...(5)(すなわち50%の確率で)
           [ifelse (random 2) = 0       ;; 50% chance of trading $5 or $2      ;; (5)が真である場合、ランダムに0～2よりも小さい値({0,1})を生成し、0であるかチェックし...(6)(すなわち50%の確率で)
              [ask customer [set wallet wallet + 5] ;;give 5 to customer       ;; (6)が真である場合、customerのwalletに5を足す
               set wallet (wallet - 5) ];;take 5 from wallet                   ;; 上記の条件の続きで、自身のwalletから5を引く
              [ask customer [set wallet wallet + 2] ;;give 2 to customer       ;; (6)が偽である場合、customerのwalletに2を足す
               set wallet (wallet - 2) ];;take 2 from wallet                   ;; 上記の条件の続きで、自身のwalletから2を引く
           ]                            ;; (5)の範囲の終了
        ]                               ;; (4)の範囲の終了
     ]                                  ;; (3)の範囲の終了
end


;; turtleのwallet, savings, loansのやり取りをする関数
;;
;; First checks balance of the turtle's wallet, and then either puts
;; a positive balance in savings, or tries to get a loan to cover
;; a negative balance.  If it cannot get a loan (if bank-to-loan < 0)
;; then it maintains the negative balance until the next round.  It
;; then checks if it has loans and money in savings, and if so, will
;; proceed to pay as much of that loan off as possible from the money
;; in savings.
to balance-books
  ifelse (wallet < 0)                       ;; もし、walletが0よりも大きいかチェックし...(7)
    [ifelse (savings >= (- wallet))         ;; (7)が真であるならば(walletが負である)、もし、savingsが(負の値を正の値に変換した)wallet以上であるかチェックし...(8)
       [withdraw-from-savings (- wallet)]   ;; (8)が真であるらなば、withdraw-from-savings関数(引数の金額分、walletに足し、savingから引く)を実行する。このとき、(負の値を正の値に変換した)walletを引数に渡す
       [if (savings > 0)                    ;; もし、savingsが0より大きいかチェックし...(9)
          [withdraw-from-savings savings]   ;; (9)が真であるならば、withdraw-from-savings関数(引数の金額分、walletに足し、savingから引く)を実行する。このとき、(負の値を正の値に変換した)savingsを引数に渡す

        if (bank-to-loan > 0)
        [
          set temp-loan bank-to-loan          ;;temp-loan = amount available to borrow ;; temp-loanにbank-to-loanを入れる
          ifelse (temp-loan >= (- wallet))    ;; temp-loanが（負の値を正の値に変換した)wallet以上であるかチェックし、 ...(10)
            [take-out-loan (- wallet)]        ;; (10)が真であるならば、take-out-loan関数(引数の金額分、loansとwalletに足し、bank-to-loanから引く)を実行する。このとき、(負の値を正の値に変換した)walletを引数に渡す
            [take-out-loan temp-loan]         ;; (10)が負であるならば、take-out-loan関数(引数の金額分、loansとwalletに足し、bank-to-loanから引く)を実行する。このとき、(負の値を正の値に変換した)temp-loanを引数に渡す
        ]
       ]
     ]
    [deposit-to-savings wallet]         ;; (7)が偽であるならば、deposit-to-savings関数(引数の金額分、walletから引き、savingsに足す)を実行する。このときwalletを引数に渡す
  if ((loans + interest-loans) > 0 and savings > 0)            ;; when there is money in savings to payoff loan ;; もし、loansとsavingsが0より大きいかチェックし...(11)
    [ifelse (savings >= (loans + interest-loans)) ;; (11)が真であるならば、savingsが(loans * (1.00 + interest/100))以上であることをチェックし、 ...(12)
       [withdraw-from-savings (loans + interest-loans)         ;; (12)が真であるならば、withdraw-from-savings関数(引数の金額分、walletに足し、savingから引く)を実行する。このとき、(負の値を正の値に変換した)walletを引数に渡す
        repay-a-loan (loans + interest-loans)]                 ;; 上記の続きで、repay-a-loan関数関数(引数の金額分 loansとwalletから引き、bank-to-loanに足す)を実行する。このとき、loansを引数に渡す
       [withdraw-from-savings savings       ;; (13)が偽であるならば、withdraw-from-savings関数(引数の金額分、walletに足し、savingから引く)を実行する。このとき、savingsを引数に渡す
        repay-a-loan wallet]                ;; 上記の続きで、repay-a-loan関数関数(引数の金額分 loansとwalletから引き、bank-to-loanに足す)を実行する。このとき、walletを引数に渡す
    ]                                       ;; (11)の範囲の終了
end



;; Sets aside required amount from liabilities into
;; reserves, regardless of outstanding loans.  This may
;; result in a negative bank-to-loan amount, which
;; means that the bank will be unable to loan money
;; until it can set enough aside to account for reserves.

;; プロット用のグローバル変数を更新する関数
to bank-balance-sheet ;;update monitors                         ;; モニター(プロット)更新
  set bank-deposits (sum [savings] of turtles)                  ;; turtleのsavingsの合計をbank-depositsグローバル変数に入れる
  set bank-loans sum [loans] of turtles                         ;; turtleのloansの合計をbank-loansに入れる
  set bank-interest-loans sum [interest-loans] of turtles
  set bank-reserves (reserves / 100) * bank-deposits            ;; bank-depositsグローバル変数 ｘ (スライダーの)reservesグローバル変数(%)をbank-reservesグローバル変数に入れる
  ifelse (back-profit = true)                                   ;; back-profitスイッチがONであるかチェックし、
    [set bank-to-loan (bank-deposits - (bank-reserves + bank-loans) + bank-profit)]  ;; bank-profitをbank-to-loan に足す
    [set bank-to-loan (bank-deposits - (bank-reserves + bank-loans))] ;; bank-depositsグローバル変数 から bank-reservesグローバル変数とbank-loansグローバル変数を引き、bank-to-loansグローバル変数に入れる
end


;; 利子を計算しローンを増やす
to interest_to_loans ;; fundamental proocedures
  set interest-loans interest-loans + round ((loans + interest-loans) * (interest-rate / 100.0))    ;;
end

;; プロット(Money & Loans)で使用するinterestの合計を計算する関数
to-report interest-total
  report sum [interest-loans] of turtles                  ;; turtleのloansを合計する
end


;; 貯金の入金処理を行う関数
to deposit-to-savings [amount] ;;fundamental procedures         ;; 各箇所で呼ばれる処理
  set wallet wallet - amount                                    ;; wallet変数から引数amount変数の金額を引く
  set savings savings + amount                                  ;; savings変数に引数amount変数の金額を足す
end

;; 貯金の引き出し処理を行う関数
to withdraw-from-savings [amount] ;;fundamental procedures      ;; 各箇所で呼ばれる関数
  set wallet (wallet + amount)                                  ;; wallet変数から引数amount変数の金額を足す
  set savings (savings - amount)                                ;; savings変数に引数amount変数の金額を引く
end


;; ローンの返済処理を行う関数
to repay-a-loan [amount] ;;fundamental procedures               ;; 各箇所で呼ばれる関数
  ifelse interest-loans > 0
    [repay-a-interest-loans amount]
    [set loans (loans - amount)                                ;; loans変数から引数amount変数の金額を引く
     set bank-to-loan (bank-to-loan + amount)
    ]
  set wallet (wallet - amount)                                  ;; wallet変数から引数amount変数の金額を引く
  ;;set bank-to-loan (bank-to-loan + amount)                      ;; bank-to-loanグローバル変数に引数amount変数の金額を足す
end

to repay-a-interest-loans [amount]
  ifelse interest-loans >= amount
      [set bank-profit (bank-profit + amount)
       set interest-loans interest-loans - amount
      ]
      [set loans (loans - (amount - interest-loans))
       set bank-to-loan (bank-to-loan + (amount - interest-loans))
       set loans (loans - (amount - interest-loans))
       set bank-profit (bank-profit + interest-loans)
       set interest-loans 0
      ]
end

;; ローンの借入処理を行う関数
to take-out-loan [amount] ;;fundamental procedures              ;; 各箇所で呼ばれる関数
  set loans (loans + amount)                                    ;; loans変数に引数amount変数の金額を足す
  set wallet (wallet + amount)                                  ;; wallet変数に引数amount変数の金額を足す
  set bank-to-loan (bank-to-loan - amount)                      ;; bank-to-loan変数から引数amount変数の金額を引く
end


;; プロット(Savings & Wallets)で使用するsavingsの合計を計算する関数
to-report savings-total
  report sum [savings] of turtles                ;; turtleのsavingを合計する
end


;; プロット(Money & Loans)で使用するloansの合計を計算する関数
to-report loans-total
  report sum [loans] of turtles                  ;; turtleのloansを合計する
end


;; プロット(Savings & Wallets)で使用するwalletの合計を計算する関数
to-report wallets-total
  report sum [wallet] of turtles                 ;; turtleのwalletを合計する
end


;; プロット(Money & Loans)で使用するmoneyの合計を計算する関数
to-report money-total
  report sum [wallet + savings] of turtles       ;; turtleのwalletとsavingsを合計する
end


; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
262
10
576
325
-1
-1
18.0
1
10
1
1
1
0
1
1
1
-8
8
-8
8
1
1
1
ticks
30.0

SLIDER
137
52
259
85
people
people
0.0
200.0
50.0
1.0
1
NIL
HORIZONTAL

SLIDER
1
52
136
85
reserves
reserves
0.0
100.0
50.0
1.0
1
NIL
HORIZONTAL

BUTTON
37
10
126
47
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
145
10
232
47
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
3
362
246
560
Money & Loans
Time
Mny + Lns
0.0
300.0
-50.0
600.0
true
true
"set-plot-x-range 0 x-max\nset-plot-y-range -50 y-max" ""
PENS
"money" 1.0 0 -16777216 true "" "plot money-total"
"loans" 1.0 0 -2674135 true "" "plot loans-total"
"interest-total" 1.0 0 -7500403 true "" "plot interest-total"
"bank-to-loan" 1.0 0 -955883 true "" "plot bank-to-loan"
"bank-profit" 1.0 0 -6459832 true "" "plot bank-profit"

MONITOR
143
141
258
186
Wallets Total
wallets-total
2
1
11

MONITOR
143
92
258
137
Savings Total
savings-total
2
1
11

MONITOR
143
190
258
235
Loans Total
loans-total
2
1
11

MONITOR
18
92
143
137
Money Total
money-total
2
1
11

MONITOR
18
190
143
235
Bank Reserves
bank-reserves
2
1
11

MONITOR
18
141
143
186
Bank to Loan
bank-to-loan
2
1
11

PLOT
249
362
509
560
Savings & Wallets
Time
Svngs + Wllts
0.0
300.0
-50.0
600.0
true
true
"set-plot-x-range 0 x-max\nset-plot-y-range -50 y-max" ""
PENS
"savings" 1.0 0 -13345367 true "" "plot savings-total"
"wallets" 1.0 0 -10899396 true "" "plot wallets-total"

PLOT
581
144
844
342
Income Dist
Time
People
0.0
300.0
0.0
57.0
true
true
"set-plot-x-range 0 x-max\nset-plot-y-range 0 (count turtles)" ""
PENS
"rich" 1.0 0 -10899396 true "" "plot rich"
"middle" 1.0 0 -16777216 true "" "plot middle-class"
"poor" 1.0 0 -2674135 true "" "plot poor"

PLOT
513
362
826
560
Wealth Distribution Histogram
poor <--------> rich
People
0.0
100.0
0.0
57.0
false
false
"set-plot-y-range 0 (count turtles)" ""
PENS
"hist" 1.0 0 -13345367 true "" "if( ticks mod 10 = 1 ) [\n  let max-wealth max [wealth] of turtles\n  let min-wealth min [wealth] of turtles\n  let one-fifth-wealth 0.2 * (max-wealth - min-wealth)\n  let num-bins 10\n  let index 1\n  let interval round ((plot-x-max - plot-x-min) / num-bins)\n  plot-pen-reset\n  repeat num-bins [\n    plotxy ((index - 1) * interval + 0.002)\n                 (count turtles with [\n                      wealth < (min-wealth + index * one-fifth-wealth) and\n                      wealth >= (min-wealth + (index - 1) * one-fifth-wealth)\n                  ]\n                 )\n\n    plotxy  (index * interval)\n                 (count turtles with [\n                      wealth < (min-wealth + index * one-fifth-wealth) and\n                      wealth >= (min-wealth + (index - 1) * one-fifth-wealth)\n                  ]\n                 )\n\n    plotxy (index * interval + 0.001) 0\n    set index index + 1\n  ]\n]"

SLIDER
139
286
256
319
interest-rate
interest-rate
0
5
4.0
1
1
NIL
HORIZONTAL

SLIDER
139
322
256
355
target
target
0
100
0.0
1
1
NIL
HORIZONTAL

SWITCH
33
322
136
355
gramin
gramin
1
1
-1000

SWITCH
32
286
137
319
back-profit
back-profit
0
1
-1000

MONITOR
18
238
143
283
Bank interest loans
bank-interest-loans
0
1
11

MONITOR
143
238
258
283
Bank profit
bank-profit
0
1
11

@#$#@#$#@
## WHAT IS IT?

This program models the creation of money in an economy through a private banking system. As most of the money in the economy is kept in banks but only little of it needs to be used (i.e. in cash form) at any one time, the banks need only keep a small portion of their savings on-hand for those transactions. This portion of the total savings is known as the banks' reserves.

The banks are then able to loan out the rest of their savings. The government (the user in this case) sets a reserve ratio mandating how much of the banks' holdings must be kept in reserve at a given time. One 'super-bank' is used in this model to represent all banks in an economy. As this model demonstrates, the reserve ratio is the key determiner of how much money is created in the system.

## HOW IT WORKS

In each round, people (represented by turtles) interact with each other to simulate everyday economic activity. Given a randomly selected number, when a person is on the same patch as someone else it will either give the person two or five dollars, or no money at all. After this, people must then sort out the balance of their wallet with the bank. People will put a positive wallet balance in savings, or pay off a negative balance from funds already in savings. If the savings account is empty and the wallet has a negative balance, a person will take out a loan from the bank if funds are available to borrow (if bank-to-loan > 0). Otherwise the person maintains the negative balance until the next round. Lastly, if someone has money in savings and money borrowed from the bank, that person will pay off as much of the loan as possible using the savings.

## HOW TO USE IT

The RESERVES slider sets the banking reserve ratio (the percentage of money that a bank must keep in reserve at a given time). The PEOPLE slider sets the number of people that will be created in the model when the SETUP button is pressed. The SETUP button resets the model: it redistributes the patch colors, creates PEOPLE people and initializes all stored values. The GO button starts and stops the running of the model and the plotter.

There are numerous display windows in the interface to help the user see where money in the economy is concentrated at a given time. SAVINGS-TOTAL indicates the total amount of money currently being kept in savings (and thus, in the banking system). The bank must then allocate this money among three accounts: LOANS-TOTAL is the amount the bank has lent out, BANK-TO-LOAN is the amount that the bank has available for loan, and BANK-RESERVES is the amount the bank has been mandated to keep in reserve. When the bank must recall loans (i.e. after the reserve ratio has been raised) BANK-TO-LOAN will read a negative amount until enough of the lent money has been paid off. WALLETS-TOTAL gives an indication of the total amount of money kept in peoples' wallets. This figure may also be negative at times when the bank has no money to loan (the turtle will maintain at a negative wallet balance until a loan is possible). MONEY-TOTAL indicates the total-amount of money currently in the economy (SAVINGS-TOTAL + WALLETS-TOTAL).  Because WALLETS-TOTAL is generally kept at 0 in this model (we are assuming that everyone deposits all they can in savings), MONEY-TOTAL and SAVINGS TOTAL tend to be the the same.

A person's color tells us whether it has money in savings (green) or is in debt (red).

## THINGS TO NOTICE

Note how much money is in MONEY-TOTAL after pressing SETUP, but before pressing GO. The total amount of money that can be created will be this figure:

(the initial money in the system) * (1 / RESERVES).

If the RESERVES remains constant through the run of the model, notice how the plot levels off at this value. Why is this equation descriptive of the system?

Once the amount of money in the system has hit the maximum (as calculated be the above equation), watch what happens when the RESERVES slider is set to 100. Now try setting the RESERVES slider back. Why does this happen?

The three monitors on the left of the interface (LOANS-TOTAL, BANK-TO-LOAN and RESERVES) represent the distribution of the bank's money at a given time. Try and track this distribution against SAVINGS-TOTAL, WALLETS-TOTAL and MONEY-TOTAL to understand fluctuations of money in the  system as they happen.

What effect does an increase in RESERVES generally have on TOTAL-MONEY?

Why do SAVINGS-TOTAL (yellow), LOANS-TOTAL (red) and MONEY-TOTAL (green) tend to rise and fall proportionately on the plot?

What happens to TOTAL-MONEY when the reserve ratio is initially set to 100 percent? Why?

## THINGS TO TRY

Vary the RESERVES rate as the model runs, and watch the effect this has on MONEY-TOTAL.

Set RESERVES initially to 100, and watch the effect on TOTAL-MONEY. Now try lowering RESERVES.

Try setting the reserve rate to 0. What would happen if this were done in a real economy?

## EXTENDING THE MODEL

Try extending the model to include payments of interest in the banking system. People with money deposited in savings should be credited with interest on their account (at a certain rate) from the bank from time to time. People with money on loan should make interest payments on their account to the bank from time to time.

This model has turtles interact in a very simple way to have money change hands (and create a need for loans). Try changing the model so that money moves around the system in a different way.

## RELATED MODELS

Wealth Distribution looks at how the reserve ratio affects the distribution of wealth.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Bank Reserves model.  http://ccl.northwestern.edu/netlogo/models/BankReserves.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1998 2001 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

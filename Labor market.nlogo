;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Labor market model extended with social network job search matching 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

extensions[csv nw table rnd] ;; For reading/writing CSV files; create network; store temporatory date in table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Agent 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

breed [seekers seeker]
breed [companies company]
breed [vacancies vacancy]
breed [agencies agency]          ; Represents intermediaries that may help match job seekers and companies.
undirected-link-breed [PSNs PSN] ; Personal social network links
PSNs-own [weight]                ; Represents the weight of the influence of social network resources
undirected-link-breed [NGs NG]   ; Negotiation link between seeker and vacancy
NGs-own[competence Nwage]
undirected-link-breed [EMPs EMP] ; Employment link between seeker and company

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Global variable
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
globals [
  unemployment-history
  vacancy-history
  mean-wage-history
  market-tightness  ;;Labor market tension (number of jobs/number of unemployments)
  log-income-bins
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Job seeker
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
seekers-own [
  unemployment-value ;;Value of job seekers when unemployed
 ; tolerance          ;;Tolerance of low wages,this affects the acceptance of offers below the desired salary
  offers
  best-offer
  best-wage
  AS?                ;;Whether or not to search aggressively,deciding whether or not to use enhanced social network searches
  my-company
  expected-wage      ;;Expected wages of job seekers, dynamically changing during initialization and negotiation
  prestige           ;;To calculate Network Resource Index
  NRI                ;;Network Resource Index decides the value if the company hires the agent
  offer-list
  duration           ;;Unemployment duration
  skill-level
  strategy-set
  education-level
  work-experience
  sex
  age
  degree
  graduates?
  daily-contacts   ;; A randomly generated number of daily contacts (between 6 and 10), used to form social ties.
  salary
  expected-salary
  job-seeked?      ;; Whether employed or not
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Company
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
companies-own [
  ;;social-impact      ;TBD
  vaca                ;; A dynamic list of current vacancies linked to the company.
  std-production      ;; Standard value
  mean-production     ;; Placeholder variables intended for tracking variability in company output.
  production-level    ;; The firm's current production capacity, which is influenced by successful hiring and strategic adjustments.
  ;growth-rate         ;; A factor to simulate productivity growth (currently static but extendable with stochastic elements).
  hiring-value        ;; A derived variable calculated from the value of filled positions and the social capital (NRI) of hired seekers.;
  Etype               ;; Ownership type of the firm, categorized as public (pub), independent (ind), or foreign-funded (for), assigned probabilistically to reflect market structure.
  hired-list          ;; A container to keep track of recruited seekers.
  position-adjustment ;; Determines whether new positions will be added or reduced in the next round, based on productivity.
  total-cost          ;; Reserved for accounting total hiring and wage expenditures.
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Job vacancy
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vacancies-own[
  vacancy-value  ;; The economic value of the job opening to the company.
  age            ;; Tracks how long the vacancy has remained open; older vacancies may increase wages to attract applicants.
  candidate-list ;; The list of seekers who have applied or been recommended for the vacancy.
  wage          ;; The offered salary, subject to negotiation based on candidate expectations and fit.
  average-demand
  filled-value  ;; The value if the vacancy is occupied.
  offered-wage  ;; The initial salary
  filled?       ;; Boolean indicating whether the position has been filled.
  MC            ;; The mother company (employer) managing the vacancy
  skill-demand  ;; The skill level required for the position (1 = low, 2 = medium, 3 = high).
  industry      ;; A reserved attribute to represent sectoral classification.
  hiring?       ;;whether this job is still hiring
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Agency;;TBD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
agencies-own [
  matching-efficiency ;; Represents the agency’s effectiveness in connecting seekers with appropriate vacancies.
  reigistered-workers];; A list or count of job seekers enrolled with the agency.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Social network setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to generate-network
 create-companies 235 [setup-companies]
 nw:generate-watts-strogatz seekers PSNs 1000 2 0.1  ; Set up small-world network
 ask PSNs [set weight 1]
 setup-seekers
 repeat 25 [layout-spring turtles PSNs 0.8 30 1.5]   ; Visualize the layout of social networks
 ask links [hide-link]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Create job seeker 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-seekers
 ask seekers [
 set shape "person"
    ;set my-company nobody
    set AS? false ;Whether to use agency search strategy
    ;; Set initial employment status
   set my-company
    ifelse-value random-float 1 < jobless-rate
    [nobody]          ; According to the unemployment rate ratio, some people will be unemployed from the beginning
    [one-of companies]; Otherwise, hire randomly to a company
    if my-company != nobody [
      set color green ; Green for employed people
      create-EMP-with my-company ; Create a Employment Link（EMP link）
      move-to one-of [patches in-radius 5] of my-company ; Create an EMP link
    ]
    ;; Set skill-level (artificially divided into 3 levels)
    let SL-i random-float 1
    set skill-level (
      ifelse-value SL-i < 0.1 [random-float 3 + 13] ; 15% High Skill
      SL-i < 0.25 [random-float 3 + 10]               ; 25% Medium Skill
      SL-i < 0.4 [random-float 3 + 7]
      SL-i < 0.65 [random-float 3 + 4]
      [random-float 3 + 1]                          ; 60% Low Skill
    )
    ;; Set expected salary: minimum salary + skills * 1000
    ;let base-wage  skill-level * 200 + minimum-wage

let bin rnd:weighted-one-of-list log-income-bins [ [x] -> last x ]
let lower first bin
let upper item 1 bin
let log-income lower + random-float (upper - lower)
set expected-wage exp(log-income) * (1 + (skill-level / 20))
    ;set expected-wage 10 ^ sample-log-income * (1 + skill-level / 20.0)

    ;set tolerance 0.01 ; Tolerance during salary negotiation affects whether to accept an offer
    ;; The setting of social status prestige
    let prestige-i random-float 1
    set prestige (
      ifelse-value prestige-i < 0.15 [2]      ; 15% High status
      prestige-i < 0.85 [0.5]                 ; 70% Medium status
      [1]                                     ; 15% Low status
    )
    ;; Set global variables: all unemployed people set UMP

    set daily-contacts random 5 + 6 ;  6~10 contacts
    ;; Create random social links through daily-contacts (no duplication with already connected people)
    create-PSNs-with
      n-of daily-contacts other seekers who-are-not link-neighbors
      [set weight 0.5] ; The strength of the initial social relationship is 0.5
  ]
  ;set UMP seekers with [my-company = nobody]
    ask seekers with [my-company = nobody] [set color red] ; The unemployed are shown in red
  ;; Calculate NRI：Network Resource Index，Used to simulate the ability of a person to get help through social interaction.
  ask seekers [
  set NRI sum [prestige * [weight] of PSN-with myself] of PSN-neighbors

  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Create agency 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-agencies
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Create company 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-companies
 setxy random 10 - 5 random 10 - 5 set color white set shape "house"
 set vaca no-turtles                                                ;; Initialization The company has no vacancy yet
 set production-level 10                                            ;; The default company productivity level is set to 10
 let Ei random-float 1                                              ;; precent of company type
 set Etype (ifelse-value Ei < 0.6 ["pub"] Ei < 0.35 ["ind"] ["for"]);; 60% public,25% indepedent,15% foreign
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Model initialization setup 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
to setup
  ca
  set log-income-bins
    [[6.2   6.4   0.000348675034867503]
    [6.4   6.6   0.000174337517433752]
    [6.6   6.8   0.000698700348675035]
    [6.8   7.0   0.000698700348675035]
    [7.0   7.2   0.00157103757103757]
    [7.2   7.4   0.00362811791280149]
    [7.4   7.6   0.00675034867503486]
    [7.6   7.8   0.0128840970350404]
    [7.8   8.0   0.0215402843601896]
    [8.0   8.2   0.0333216726220632]
    [8.2   8.4   0.0445386192310276]
    [8.4   8.6   0.0542782288111644]
    [8.6   8.8   0.0583664459161148]
    [8.8   9.0   0.0568432407763511]
    [9.0   9.2   0.0510662177329532]
    [9.2   9.4   0.0422757051773294]
    [9.4   9.6   0.0333962729316361]
    [9.6   9.8   0.0272430472648114]
    [9.8  10.0   0.0208178785056326]
    [10.0 10.2   0.0163269605372615]
    [10.2 10.4   0.0138058540841553]
    [10.4 10.6   0.0112847476310491]
    [10.6 10.8   0.00801423723490814]
    [10.8 11.0   0.00586703096539162]
    [11.0 11.2   0.00464322638324506]
    [11.2 11.4   0.00326982097109785]
    [11.4 11.6   0.00219821382605634]
    [11.6 11.8   0.00139600928620765]
    [11.8 12.0   0.000698700348675035]
  ]
  generate-network
  initialize-vacancies
  ;; Initialize records
  set unemployment-history []
  set vacancy-history []
  set mean-wage-history []
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; initialize-vacancies
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to initialize-vacancies
  let total-vacancies 635
  let target-initial-unfilled 235
  while [count vacancies < total-vacancies] [
    ask one-of companies [
      hatch-vacancies 1 [

        let bin rnd:weighted-one-of-list log-income-bins [ [x] -> last x ]
        let lower first bin
        let upper item 1 bin
        let log-income lower + random-float (upper - lower)

        set hiring? true
        let SD-i random-float 1
        set skill-demand (
          ifelse-value SD-i < 0.1 [random-float 3 + 13]
          SD-i < 0.25 [random-float 3 + 10]
          SD-i < 0.4 [random-float 3 + 7]
          SD-i < 0.65 [random-float 3 + 4]
          [random-float 3 + 1]
        )
        set shape "dot"
        set color brown
        set MC myself
        set filled-value 0
        set offered-wage exp(log-income) * (1 + skill-demand / 20)
        set age 0

        set filled? (count vacancies > target-initial-unfilled)


        move-to mc rt random 360 fd 1.5 set size 1
      ]
    ]
  ]

  ask vacancies [create-EMP-with MC]
  ask companies [set vaca vacancies with [EMP-neighbor? myself = true]]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Model simulation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
to go
  if ticks >= 156 [
    export-wage-data
   ;export-beveridge-data
    stop
  ]    ;; The first 12 monthes are warm-up ，The simulation duration is set to 500 ticks
 ;update-environment          ;; Update the current tightness of the labor market (ratio of jobs to job seekers).
 update-seekers
 update-vacancies
   ;record-beveridge
let current-wage-mean mean [expected-wage] of seekers with [my-company != nobody]
  set mean-wage-history lput current-wage-mean mean-wage-history
   let current-unemployed-skill mean [skill-level] of seekers with [my-company = nobody]
 ; let current-opening-demand mean [skill-demand] of vacancies with [filled? = false]
show count vacancies with [filled? = false]
print(word "vac(f) " count vacancies with [filled? = false])


 tick
;;update if looking next round, update social capital, update job search status
ifelse any? seekers with [my-company = nobody]
 [ask seekers with [my-company = nobody] [search]          ;; Have all unemployed people conduct formal/informal job search.
   wage-negotiation
     update-company][stop] ;;Updating productivity, deciding on a recruitment strategy for the next round, updating vacancy

end

to update-seekers
 ;set UMP seekers with [my-company = nobody]    ; Filter out all job seekers who are currently unemployed
   ask seekers with [my-company = nobody] [
   set offers nobody                           ; Initialization: Clear the job opportunities received by each unemployed person.
       set duration duration + 1 ;; The longer you are unemployed, the more you tolerate low-wage jobs，
   set tolerance tolerance + 0.01
    if ticks mod 10 = 0 [set expected-wage expected-wage * 0.95]

   ; If a job seeker has been unemployed for more than one year or has a skill level below 2, there is an 80% chance that he or she will start looking for a job through an agency search.
   if AS? = 0 and (duration > 12 or skill-level < 2) [if random-float 1 < 0.8 [set AS? 1]]
   set NRI NRI * 0.9 + 0.1 * count PSN-neighbors with [my-company != nobody]/ count PSN-neighbors
   set unemployment-value 0.6 * expected-wage + 0.4 * 0.8 * minimum-wage] ;Estimating the utility of unemployment
  print (word "initial UMP count: " count seekers with [my-company = nobody])

end


to update-vacancies
  ask vacancies[ set age age + 1
    ;Simulate the situation in real life when recruitment is difficult and companies raise salaries to attract talent.
    if age > 5 [set offered-wage offered-wage * 1.05]] ;After a position exists for more than 5 ticks, the salary will increase by 5%
end

;;Job search process
to search
  ;; Initialize the recommended variables to empty
let recommendation no-turtles
  ;; Set the sensitivity parameter for wage-skill matching
let wage-eclasity 0.02 let skill-eclasity 1 / 14
  ;; Maximum number of positions to search each time
let search-unit 5
  ;; Social network recommendations: filter positions from friends' companies (my-company is not empty)
 let social-search turtle-set [vaca] of (turtle-set [my-company] of PSN-neighbors with [my-company != nobody])
  ;; If the candidate is an enabled candidate (AS? = true)
if AS? [set search-unit (round search-unit * 1.5) ;; Increase the intensity of active search
    set recommendation n-of 2 vacancies with [1 - (skill-demand / [skill-level] of myself) < 1.1]] ;;Mandatory recommendation of 2 positions that match agent's skills
; Filter socially recommended positions that match your skills and salary expectations
  set social-search (social-search) with [abs (1 - skill-demand / [skill-level] of myself) < [skill-eclasity] of myself and (abs 1 - offered-wage / [expected-wage] of myself) < wage-eclasity]
; Search through formal channels (job board, etc.) for positions that meet the requirements
  let formal-search vacancies with [abs (1 - skill-demand / [skill-level] of myself) < skill-eclasity and (abs 1 - offered-wage / [expected-wage] of myself) < wage-eclasity]
 set formal-search n-of min (list count formal-search search-unit) formal-search
; Integrate all possible job opportunities (formal + social + recommendation)
  set offers (turtle-set formal-search social-search recommendation)
; Create a candidate connection (NG link = a negotiation connection between a job seeker and a position)
 create-NGs-with offers [ set color yellow set competence ([skill-level] of myself - [skill-demand] of other-end) * σ - ([expected-wage] of myself - [offered-wage] of other-end)]
end


;;Bargining for wage
to wage-negotiation
  ask vacancies with [count NG-neighbors > 0]
  ;; Start negotiations for each position with a candidate
  [set average-demand mean [expected-wage] of NG-neighbors
    let vaca-now self
    ;For each candidate (sort by competence from high to low)
    foreach sort-on [[0 - competence] of NG-with myself] NG-neighbors [? -> if filled? != false
     [let ewage [expected-wage] of ?
        ;; First offer = sticky part * (unemployment value + average expected salary + strategic reward)
      let first-wage ε * (0.5 * ([unemployment-value] of ? + 0.5 * average-demand ) + (500 * strategy-bonus ?)) + (1 - ε) * offered-wage
        ;; Salary negotiation: Consider skills match
      let bargain-wage ewage * ([skill-level] of ? / skill-demand) * σ
      let final-wage β * first-wage + (1 - β) * bargain-wage
        ;; Update personal best offer
        ask ? [if final-wage > [best-offer] of ? [set best-offer final-wage]]
      ask NG-with ? [set Nwage final-wage]
        ;; To check if the candidate is willing to accept
      let willingness ((final-wage - ewage) / ewage) / (-1 * [tolerance] of ?)
          (ifelse willingness > 1.5 [ask vaca-now [onboard ? set filled? true set hiring? false]]
            willingness > 1
            [ask NG-with ? [die]
              ]
  )]]]
        ;; All job seekers without a company, if they are still looking for a job, will choose the job with the highest bid
  ask seekers [while [my-company = nobody and count my-in-NGs > 0] [if any? my-in-NGs [let targetVlink max-one-of my-in-NGs [Nwage]
    ask [other-end] of targetVlink [onboard myself]]]]
  end

to-report strategy-bonus [x]
 let Fmethod 0
 if [AS?] of x = 1 [set Fmethod 0.5]
 let Gbonus1 0 let Gbonus2 0
  ;; Graduate bonus points
 ifelse [graduates?] of x = true [set Gbonus1 100][set Gbonus1 0]
 (ifelse [Etype] of mc = "PUB" [set Gbonus2 1.5] [Etype] of mc = "IND" [set Gbonus2 1] [set Gbonus2 0])
let Gbonus Gbonus1 * Gbonus2
 report Gbonus * (Fmethod + 1)
end


;;update the value
to onboard [wk]
  set filled? true
  let nlink ng-with wk
  set wage [Nwage] of nlink
    ;; Company productivity calculation
  set filled-value filled-value * ([skill-level] of wk / skill-demand * σ)
    ;; Job seeker update status
  ask wk [set expected-wage max (list expected-wage [Nwage] of nlink) set my-company [MC] of myself move-to one-of [patches in-radius 5] of my-company set color green]
    ;; Update company recruitment score
  ask MC [set hiring-value hiring-value + ([filled-value - wage] of myself)]
  ;; Clear the original negotiation connection
  print (word "Hired: " [who] of wk " | Company: " [who] of MC)
  ask my-NGs [die]

end

to update-company
 ask companies
 [set hiring-value hiring-value + 0.03 * (sum [NRI] of seekers with [my-company = myself]) ;; Update company recruitment scores based on job seeker willingness values
 ;; Production level forecast
 let anticipated-production-level production-level * (1 + growth-rate) + risk-buffer ;;growth-rate暂定为0，按照实际情况决定。同时建议growth-rate引入随机波动。
   set production-level production-level + hiring-value
   foreach range 15 [? -> let FV vaca with [filled? = true and (skill-demand - ?) ^ 2 < 1]
   if any? FV [let mean-wage mean [wage] of FV
   let department-hiring-value sum [filled-value - wage] of FV
        ;; If actual output is higher than forecast, expand job positions
     if production-level > anticipated-production-level [
    let new-vacancies (floor (production-level - anticipated-production-level)) + random 3
    hatch-vacancies new-vacancies [
      set skill-demand skill-demand  ;; Inheriting existing skill requirements
      set offered-wage mean-wage
      set MC myself
      create-EMPs-with (turtle-set MC)
      move-to one-of [patches in-radius 3] of MC
    ]
  ]
        ;; If output is low, jobs will be eliminated
       if position-adjustment < 0 [let nvacas count vaca with [skill-demand = ?] ask n-of min (list (nvacas) (-1 * position-adjustment)) vaca with [skill-demand = ?] [set filled? true]]]]]
     ask vacancies with [filled? = true][die]

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;; Statistics and reporting process 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report risk-buffer
  let delta production-level - mean-production
  ;; Update mean production
  set mean-production (mean-production * (ticks - 1) + production-level) / ticks
  ;; Update standard production
  ifelse ticks - 1 > 0 [
    set std-production sqrt (delta * (production-level - mean-production) / (ticks - 1))
  ][
    set std-production 0
  ]
  ;; Returns the risk buffer value as a multiple of the 95% confidence interval
  report 1.96 * std-production
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;;Data storage and export 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-wage-data
  file-open "final-data.csv"
  let wage-list [Nwage] of seekers with [my-company != nobody]
  foreach wage-list [w -> file-print w ]
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
361
23
798
461
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
102
24
168
57
NIL
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
207
24
270
57
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
95
122
187
155
minimum-wage
minimum-wage
0
5000
500.0
500
1
NIL
HORIZONTAL

SLIDER
90
216
187
249
jobless-rate
jobless-rate
0
1
0.6
0.1
1
NIL
HORIZONTAL

SLIDER
94
76
186
109
A
A
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
198
123
290
156
α
α
0
1
0.2
0.1
1
NIL
HORIZONTAL

PLOT
816
25
1016
175
Mean Expected Wage Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks mean [expected-wage] of seekers with [my-company != nobody]\n"

PLOT
819
196
1019
346
Unemployment rate
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count seekers with [my-company = nobody]\n"

SLIDER
199
166
291
199
σ
σ
0
1
0.65
0.05
1
NIL
HORIZONTAL

MONITOR
100
290
158
335
UMP
count seekers with [my-company = nobody]
17
1
11

MONITOR
229
291
302
336
vacancies
count vacancies
17
1
11

SLIDER
93
168
185
201
growth-rate
growth-rate
-1
1
0.0
0.1
1
NIL
HORIZONTAL

MONITOR
99
343
217
388
Unemployment rate
count seekers with [my-company = nobody] / count seekers
3
1
11

MONITOR
226
400
334
445
Beveridge Ratio
count vacancies / count seekers with [my-company = nobody]
3
1
11

MONITOR
573
483
780
528
Mean Expected Wage (Employed)
mean [expected-wage] of seekers with [my-company != nobody]
3
1
11

MONITOR
362
484
567
529
Mean Expected Wage (Unemployed)
mean [expected-wage] of seekers with [my-company = nobody]
3
1
11

MONITOR
98
450
212
495
Average Tolerance
mean [tolerance] of seekers
3
1
11

MONITOR
94
556
253
601
Mean NRI (Unemployed)
mean [NRI] of seekers with [my-company = nobody]
3
1
11

MONITOR
95
504
237
549
Mean NRI (Employed)
mean [NRI] of seekers with [my-company != nobody]
3
1
11

MONITOR
226
451
353
496
Mean Vacancy Age
mean [age] of vacancies
3
1
11

MONITOR
97
396
220
441
Mean Vacancy Wage
mean [wage] of vacancies
17
1
11

PLOT
1038
25
1238
175
Tolerance Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [tolerance] of seekers"

PLOT
822
364
1022
514
Beveridge Curve (V/U)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count seekers with [my-company = nobody] / count seekers\n"
"pen-1" 1.0 0 -7500403 true "" "plot count vacancies with [filled? = false] / count vacancies"

SLIDER
89
255
210
288
ε
ε
0
1
0.27
0.01
1
NIL
HORIZONTAL

SLIDER
200
215
302
248
β
β
0
1
0.5
0.1
1
NIL
HORIZONTAL

MONITOR
232
247
289
292
vac(f)
count vacancies with [filled? = false]
3
1
11

MONITOR
388
565
480
610
mean skill(u)
mean [skill-level] of seekers with [my-company = nobody]
3
1
11

MONITOR
487
565
614
610
mean skill demand
mean [skill-demand] of vacancies with [filled? = false]
3
1
11

MONITOR
228
343
318
388
vacancy rate
count vacancies with [filled? = false] / count vacancies
3
1
11

SLIDER
197
75
303
108
tolerance
tolerance
0
0.1
1218.9599999990364
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
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


#整合怀孕状态
DROP TABLE IF EXISTS `young_status_table`;
create table young_status_table
select num,date,status from
 (select num,date,"产犊" status
from calving
union
(select num,date,"流产" status
from abortion)
union
(select num,date,"发情" status
from estrus)
union
(select num,date,"配种" status
from breeding)
union
(select num,date,"禁配" status
from breeding_forbid)
union
(select num,date,"解禁" status
from breeding_allow)
union
(select num,date,result status
from pregnancy_check_again)
union
(select num,date,result
from pregnancy_check_first)) s;

#情期初节点前的所有牛的所有繁育状态：
DROP TABLE IF EXISTS `young_begin_status`;
create table young_begin_status
select num,date,status
from status_table
where date <=(select start_date from 21_interval where id=1);

#情期初节点(已考虑：节点时的胎次，日龄，怀孕状态，禁配),young_start_table

#情期初的月龄符合的后备牛，且未孕
DROP TABLE IF EXISTS `young_start_table`;
create table young_start_table
select unpreg.num num,could_be_bred_replace_cow.birthday_to_start birthday_to_start
from
(select latest_table.num num, latest_table.latest_status status
from
(select
num,
(select s2.status
from young_begin_status s2
where s2.num=s1.num
order by s2.date desc limit 1
)  latest_status
from young_begin_status s1 
group by num) latest_table
where latest_status in ("流产","发情","配种","初检-","复检-"))unpreg,
(select replace_cow.num num,replace_cow.birthday_to_start
from
(select num,datediff((select start_date from 21_interval where id=1),birthday) birthday_to_start
from info
where gender="母" and num not in
(select
calving_cow.calving_num num
from
(select info.num calving_num,calving_time.cnt c_cnt
from info,
(select num,count(1) cnt
from calving
where date <=(select start_date from 21_interval where id=1)
group by num) calving_time
where info.num=calving_time.num and info.birthday<=
(select start_date from 21_interval where id=1) and disappearing_date>
(select start_date from 21_interval where id=1)) calving_cow) and birthday<=
(select start_date from 21_interval where id=1) and disappearing_date>
(select start_date from 21_interval where id=1)) replace_cow
where replace_cow.birthday_to_start>(14*30.4)) could_be_bred_replace_cow
where could_be_bred_replace_cow.num=unpreg.num;




#情期末节点前的所有牛的所有繁育状态：
DROP TABLE IF EXISTS `young_end_status`;
create table young_end_status
select num,date,status
from status_table
where date <=(select end_date from 21_interval where id=1);


#情期末节点(已考虑：节点时的胎次，日龄，怀孕状态，禁配),young_end_table

#情期末的月龄符合的后备牛，且未孕
DROP TABLE IF EXISTS `young_end_table`;
create table young_end_table
select unpreg.num num,could_be_bred_replace_cow.birthday_to_end birthday_to_end
from
(select latest_table.num num, latest_table.latest_status status
from
(select
num,
(select s2.status
from young_end_status s2
where s2.num=s1.num
order by s2.date desc limit 1
)  latest_status
from young_end_status s1 
group by num) latest_table
where latest_status in ("流产","发情","配种","初检-","复检-"))unpreg,
(select replace_cow.num num,replace_cow.birthday_to_end
from
(select num,datediff((select end_date from 21_interval where id=1),birthday) birthday_to_end
from info
where gender="母" and num not in
(select
calving_cow.calving_num num
from
(select info.num calving_num,calving_time.cnt c_cnt
from info,
(select num,count(1) cnt
from calving
where date <=(select end_date from 21_interval where id=1)
group by num) calving_time
where info.num=calving_time.num and info.birthday<=
(select end_date from 21_interval where id=1) and disappearing_date>
(select end_date from 21_interval where id=1)) calving_cow) and birthday<=
(select end_date from 21_interval where id=1) and disappearing_date>
(select end_date from 21_interval where id=1)) replace_cow
where replace_cow.birthday_to_end>(14*30.4)) could_be_bred_replace_cow
where could_be_bred_replace_cow.num=unpreg.num;




#情期初到情期后的45天内淘汰，并且截至到情期后的45天时，状态为配种。
#情期后的45天的所有牛的所有繁育状态：
DROP TABLE IF EXISTS `45_day_status`;
create table 45_day_status
select num,date,status
from status_table
where date <=(select DATE_ADD(end_date,INTERVAL 45 day) from 21_interval where id=1);


#头胎（情期末-情期初）+情期初-期间淘汰牛-情期后未检牛：
DROP TABLE IF EXISTS `first_unsure_cow`;
create table first_unsure_cow 
select num from 
(select num
from end_table
where cnt=1 and afterday>=60 and num not in ( select num
from start_table
where cnt=1 and afterday>=60) UNION
select num
from start_table
where cnt=1 and afterday>=60) t
where num not in
(select num
from info
where disappearing_date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)) and num not in 
(select unpreg.num
from 
(select num
from info
where disappearing_date between (select end_date from 21_interval where id=1) and (select DATE_ADD(end_date,INTERVAL 45 day) from 21_interval where id=1)) 45_day_disappearing,
(select latest_table.num num, latest_table.latest_status status
from
(select
num,
(select s2.status
from 45_day_status s2
where s2.num=s1.num
order by s2.date desc limit 1
)  latest_status
from 45_day_status s1 
group by num) latest_table
where latest_status="配种")unpreg
where unpreg.num=45_day_disappearing.num);


#校正项目，头胎牛中未过自愿期60天，提前参配牛(情期内可能多次配种，取最近配种日；最近产犊日按照情期初的最近产犊日（产后20天内配种的概率很小，因此近似取值）)


#头胎提早参配牛
DROP TABLE IF EXISTS `first_early_cow`;
create table first_early_cow 
select adult.num num
from
(select
bred.num,
datediff((select
st.date
from status_table st
where st.num=bred.num and st.status="配种" and  st.date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
order by st.date desc limit 1
),(select
st1.date
from status_table st1
where st1.num=bred.num and st1.status="产犊" and  st1.date < (select start_date from 21_interval where id=1)
order by st1.date desc limit 1
)) afterday
from
(select num
from breeding b1
where date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
group by num) bred) recent_after_calving,
(select
calving_cow.calving_num num,calving_cow.c_cnt cnt
from
(select info.num calving_num,calving_time.cnt c_cnt
from info,
(select num,count(1) cnt
from calving
where date <=(select start_date from 21_interval where id=1)
group by num) calving_time
where info.num=calving_time.num and info.birthday<=
(select start_date from 21_interval where id=1) and disappearing_date>
(select start_date from 21_interval where id=1)) calving_cow) adult
where recent_after_calving.num=adult.num and recent_after_calving.afterday<60 and adult.cnt=1;

#头胎应参配牛（校正提早牛）
DROP TABLE IF EXISTS `first_cow`;
create table first_cow
select num
from
first_early_cow
union
select num
from first_unsure_cow;




#二胎（情期末-情期初）+情期初-期间淘汰牛-情期后未检牛：
DROP TABLE IF EXISTS `delivered_unsure_cow`;
create table delivered_unsure_cow 
select num from 
(select num
from end_table
where cnt>1 and afterday>=50 and num not in ( select num
from start_table
where cnt>1 and afterday>50) UNION
select num
from start_table
where cnt>1 and afterday>=50) t
where num not in
(select num
from info
where disappearing_date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)) and num not in 
(select unpreg.num
from 
(select num
from info
where disappearing_date between (select end_date from 21_interval where id=1) and (select DATE_ADD(end_date,INTERVAL 45 day) from 21_interval where id=1)) 45_day_disappearing,
(select latest_table.num num, latest_table.latest_status status
from
(select
num,
(select s2.status
from 45_day_status s2
where s2.num=s1.num
order by s2.date desc limit 1
)  latest_status
from 45_day_status s1 
group by num) latest_table
where latest_status="配种")unpreg
where unpreg.num=45_day_disappearing.num);

#二胎提早参配牛

DROP TABLE IF EXISTS `delivered_early_cow`;
create table delivered_early_cow 
select adult.num num,adult.cnt cnt,recent_after_calving.afterday afterday
from
(select
bred.num,
datediff((select
st.date
from status_table st
where st.num=bred.num and st.status="配种" and  st.date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
order by st.date desc limit 1
),(select
st1.date
from status_table st1
where st1.num=bred.num and st1.status="产犊" and  st1.date < (select start_date from 21_interval where id=1)
order by st1.date desc limit 1
)) afterday
from
(select num
from breeding b1
where date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
group by num) bred) recent_after_calving,
(select
calving_cow.calving_num num,calving_cow.c_cnt cnt
from
(select info.num calving_num,calving_time.cnt c_cnt
from info,
(select num,count(1) cnt
from calving
where date <=(select start_date from 21_interval where id=1)
group by num) calving_time
where info.num=calving_time.num and info.birthday<=
(select start_date from 21_interval where id=1) and disappearing_date>
(select start_date from 21_interval where id=1)) calving_cow) adult
where recent_after_calving.num=adult.num and recent_after_calving.afterday<50 and adult.cnt>1;

#二胎应参配牛（校正提早牛）
DROP TABLE IF EXISTS `delivered_cow`;
create table delivered_cow
select num
from
delivered_early_cow
union
select num
from delivered_unsure_cow;




#头胎实际参配牛
DROP TABLE IF EXISTS `first_cow_bred`;
create table first_cow_bred
select first_cow.num
from first_cow,
(select num
from breeding
where date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
group by num
) bred_cow
where first_cow.num=bred_cow.num;

#二胎实际参配牛
DROP TABLE IF EXISTS `delivered_cow_bred`;
create table delivered_cow_bred
select delivered_cow.num
from delivered_cow,
(select num
from breeding
where date between (select start_date from 21_interval where id=1) and (select end_date from 21_interval where id=1)
group by num
) bred_cow
where delivered_cow.num=bred_cow.num;


#应参配牛中的受孕头胎牛（情期初，到情期节点末+60天的期间内）所有繁育行为：(配后的期间内有过妊检+的牛，可能后期复检-)，此法不按最终状态来。
DROP TABLE IF EXISTS `first_cow_preg`;
create table first_cow_preg
select num,date,status
from status_table
where status="初检+" and num in (select num from first_cow_bred) and date between (select start_date from 21_interval where id=1) and (select DATE_ADD(end_date,INTERVAL 60 day) from 21_interval where id=1);


#应参配牛中的受孕二胎及以上牛（情期初，到情期节点末+60天的期间内）所有繁育行为：(配后的期间内有过妊检+的牛，可能后期复检-)，此法不按最终状态来。
DROP TABLE IF EXISTS `delivered_cow_preg`;
create table delivered_cow_preg
select num,date,status
from status_table
where status="初检+" and num in (select num from delivered_cow_bred) and date between (select start_date from 21_interval where id=1) and (select DATE_ADD(end_date,INTERVAL 60 day) from 21_interval where id=1);



#插入成母牛21天参配受孕头数
insert into 21_result(start_date,end_date,should_be_bred_cnt,bred_cnt,preg_cnt,first_should_be_bred_cnt,first_bred_cnt,first_preg_cnt,delivered_should_be_bred_cnt,delivered_bred_cnt,delivered_preg_cnt) values(
(select start_date from 21_interval where id=1),
(select end_date from 21_interval where id=1),
((select count(1) from first_cow)+(select count(1) from delivered_cow)),
((select count(1) from first_cow_bred)+(select count(1) from delivered_cow_bred)),
((select count(1) from first_cow_preg)+(select count(1) from delivered_cow_preg)),

(select count(1) from first_cow),
(select count(1) from first_cow_bred),
(select count(1) from first_cow_preg),

(select count(1) from delivered_cow),
(select count(1) from delivered_cow_bred),
(select count(1) from delivered_cow_preg)
);


#查询（sr,cr,pr）
select start_date,end_date,bred_cnt/should_be_bred_cnt sr,preg_cnt/bred_cnt cr,preg_cnt/should_be_bred_cnt pr
from 21_result;









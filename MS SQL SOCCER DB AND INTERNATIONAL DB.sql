-- find 5 teams with the highest win percentage for each season
use soccer;
go
with t1 as 
(select season,home_team, count(iif(home_team_goal>away_team_goal,home_team,null)) as home_wins, count(home_team) as home_matches
from matches_view
group by season,home_team)
,t2 as
(select season,away_team, count(iif(away_team_goal>home_team_goal,away_team,null)) as away_wins, count(away_team) as away_matches
from matches_view
group by season,away_team)
,t3 as
(select t1.season,home_team as team,home_wins,away_wins, home_wins+away_wins as total_wins, home_matches+away_matches as total_matches,
round((cast(home_wins as float)+away_wins)/(home_matches+away_matches)*100,2) as win_percentage
from t1
join t2 on t1.home_team=t2.away_team and t1.season=t2.season)
,t4 as
(select t3.*,ROW_NUMBER() over(partition by season order by season, win_percentage desc) as 'rank'
from t3)
select *
from t4 where rank <=5;


-- find out how BMI changes over time

with t1 as
(select p.*,cast(concat(SUBSTRING(birthday,1,4),'-',SUBSTRING(birthday,6,2),'-',SUBSTRING(birthday,9,2)) as date) as birthdate
from player p)
,t2 as
(select t1.*, (weight*0.453592)/((height*height*0.0001)) as bmi, 
datediff(day,birthdate,'2016-12-31')/365 as age
from t1 )
,t3 as 
(select age,avg(bmi) as avg_BMI
from t2
group by age)
,t4 as
(select t3.*, lag(avg_BMI) over(order by age) as previous
from t3)
select t4.*, iif(avg_BMI>previous,'Increase','Decrease') as 'Increase/Decrease', 
format((avg_BMI-previous)/previous,'P2') as change_in_percent
from t4
where previous is not null and age<=36;



-- How team attributes affect team performance

with t1 as 
(select season,home_team, count(iif(home_team_goal>away_team_goal,home_team,null)) as home_wins, count(home_team) as home_matches
from matches_view
group by season,home_team)
,t2 as
(select season,away_team, count(iif(away_team_goal>home_team_goal,away_team,null)) as away_wins, count(away_team) as away_matches
from matches_view
group by season,away_team)
,t3 as
(select t1.season,home_team as team,home_wins,away_wins, home_wins+away_wins as total_wins, home_matches+away_matches as total_matches,
round((cast(home_wins as float)+away_wins)/(home_matches+away_matches)*100,2) as win_percentage
from t1
join t2 on t1.home_team=t2.away_team and t1.season=t2.season)
,t4 as
(select t3.*,ROW_NUMBER() over(partition by season order by season, win_percentage desc) as 'rank'
from t3)
,t5 as
(select season,max(rank) as max_rank
from t4
group by season)
,t6 as 
(select t4.*, iif(rank<=5,'TOP','BOTTOM') as performance
from t4
join t5 on t4.season=t5.season
where rank<=5 or rank>max_rank-5)
,t7 as 
(select t6.*,t.team_api_id,buildUpPlaySpeed,buildUpPlayDribbling,buildUpPlayPassing,chanceCreationPassing,chanceCreationCrossing,chanceCreationShooting,defencePressure,defenceAggression,defenceTeamWidth
from t6
join team t on t6.team=cast(t.team_long_name as varchar(100))
join team_attributes ta on t.team_api_id=ta.team_api_id and SUBSTRING(TA.date,1,4)=SUBSTRING(t6.season,1,4))
select performance,
avg(buildUpPlaySpeed) as buildUpPlaySpeed,
avg(buildUpPlayDribbling) as buildUpPlayDribbling,
avg(buildUpPlayPassing) as buildUpPlayPassing,
avg(chanceCreationPassing) as chanceCreationPassing,
avg(chanceCreationCrossing) as chanceCreationCrossing,
avg(chanceCreationShooting) as chanceCreationShooting,
avg(defencePressure) as defencePressure,
avg(defenceAggression) as defenceAggression,
avg(defenceTeamWidth) as defenceTeamWidth
from t7
group by performance
order by performance desc;

-- teams that have higher win percentage in the season, tend to have higher team attributes

-- FIND RIVALRIES WHERE ONE TEAM DOMINATES OVER ANOTHER IN TERMS OF WIN PERCENTAGE
USE international;
WITH T1 AS 
(SELECT concat(home_team,'-',away_team) AS RIVALRY, COUNT(HOME_TEAM) AS HOME_MATCHES ,
COUNT(IIF(home_score>away_score,home_team,NULL)) AS HOME_WIN,
COUNT(IIF(home_score<away_score,home_team,NULL)) AS HOME_LOSS,
COUNT(IIF(home_score=away_score,home_team,NULL)) AS HOME_DRAW
FROM dbo.results
GROUP BY home_team,away_team)
,T2 AS
(SELECT T1.RIVALRY, T1.HOME_MATCHES+A.HOME_MATCHES AS TOTAL_MATCHES,
ROUND((CAST(T1.HOME_WIN AS FLOAT)+A.HOME_LOSS)/(T1.HOME_MATCHES+A.HOME_MATCHES)*100,2) AS HOME_TEAM_WIN_PERCENTAGE,
ROUND((CAST(T1.HOME_LOSS AS FLOAT)+A.HOME_WIN)/(T1.HOME_MATCHES+A.HOME_MATCHES)*100,2) AS AWAY_TEAM_WIN_PERCENTAGE
FROM T1
JOIN T1 A ON substring(T1.RIVALRY,1,CHARINDEX('-',T1.RIVALRY)-1)=substring(A.RIVALRY,CHARINDEX('-',A.RIVALRY)+1,LEN(A.RIVALRY)) AND substring(T1.RIVALRY,CHARINDEX('-',T1.RIVALRY)+1,LEN(T1.RIVALRY))=substring(A.RIVALRY,1,CHARINDEX('-',A.RIVALRY)-1)
WHERE  substring(T1.RIVALRY,1,CHARINDEX('-',T1.RIVALRY)-1)<substring(T1.RIVALRY,CHARINDEX('-',T1.RIVALRY)+1,LEN(T1.RIVALRY))
)
SELECT *
FROM T2
WHERE TOTAL_MATCHES>10 AND (HOME_TEAM_WIN_PERCENTAGE<20 OR AWAY_TEAM_WIN_PERCENTAGE<20) AND RIVALRY LIKE('%GERMANY%')
ORDER BY TOTAL_MATCHES DESC;


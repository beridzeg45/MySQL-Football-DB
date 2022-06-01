### create view of matches with necessary columns(country,league,season,date,home_team, home_team_score,away_team,away_team_scored)

drop view if exists matches_view;
CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `matches_view` AS
    SELECT 
        `m`.`id` AS `id`,
        `c`.`name` AS `country`,
        `l`.`name` AS `league`,
        `m`.`season` AS `season`,
        `m`.`date` AS `date`,
        `t1`.`team_long_name` AS `home_team`,
        `m`.`home_team_goal` AS `home_team_goal`,
        `m`.`away_team_goal` AS `away_team_goal`,
        `t2`.`team_long_name` AS `away_team`
    FROM
        ((((`matches` `m`
        JOIN `country` `c` ON ((`c`.`id` = `m`.`country_id`)))
        JOIN `team` `t1` ON ((`t1`.`team_api_id` = `m`.`home_team_api_id`)))
        JOIN `team` `t2` ON ((`t2`.`team_api_id` = `m`.`away_team_api_id`)))
        JOIN `league` `l` ON ((`l`.`country_id` = `m`.`country_id`)))




# create stored procedure that returns matches view according to three optional arguments (country, home_team, away_team)

delimiter $$
create procedure get_matches(p_country varchar(55),p_home_team varchar(255),p_away_team varchar(255))
begin
	select m.id, c.name as country,l.name as league, m.season,m.date,t1.team_long_name as home_team,home_team_goal, away_team_goal,t2.team_long_name as away_team
	from matches m 
	join country c on c.id=m.country_id
	join team t1 on t1.team_api_id=m.home_team_api_id
	join team t2 on t2.team_api_id=m.away_team_api_id
	join league l on l.country_id=m.country_id
	where c.name=ifnull(p_country,c.name)
    and t1.team_long_name like concat("%",ifnull(p_home_team,t1.team_long_name),"%") 
    and t2.team_long_name like concat("%",ifnull(p_away_team,t2.team_long_name),"%");
end $$



# find teams which scored less than accepted in a season

select home.season,home_team as team, home_scored+away_scored as scored, home_accepted+away_accepted as accepted
from 
(select season,home_team,sum(home_team_goal) as home_scored, sum(away_team_goal) as home_accepted
from matches_view
group by season,home_team
order by 1,2) as home
join
(select season,away_team,sum(away_team_goal) as away_scored, sum(home_team_goal) as away_accepted
from matches_view
group by season,away_team
order by 1,2) as away
on home.season=away.season and home.home_team=away.away_team
where home_scored+away_scored<home_accepted+away_accepted;


# find  teams with the most goals scored in 2012/2013 season
select home_team as team,home_goals,away_goals,home_goals+away_goals as total_goals
from
(select home_team,sum(home_team_goal) as home_goals
from matches_view
where season="2012/2013"
group by home_team) as home
join
(select away_team,sum(away_team_goal) as away_goals
from matches_view
where season="2012/2013"
group by away_team) as away
on home.home_team=away.away_team
order by total_goals desc  

# find the leagues with the most goals scored in 2012/2013 season
select season,league, sum(home_team_goal+away_team_goal) as goals_total
from matches_view
where season="2012/2013"
group by league
order by goals_total desc

# which club (and when) scored the most goals in an entire year?

select t1.year as year,home_team as team, home_goals,away_goals, home_goals+away_goals as goals_total
from
(select year(date) as year,home_team, sum(home_team_goal) as home_goals
from matches_view
group by 1,2
order by 3 desc) as t1
join
(select year(date) as year,away_team, sum(away_team_goal) as away_goals
from matches_view
group by 1,2
order by 3 desc) as t2
on t1.home_team=t2.away_team and t1.year=t2.year
order by goals_total desc limit 1

# how many matches has bayern won against dortmund from 2008 to 2016?
select count(*)
from matches_view
where (home_team regexp "dortmund" and home_team_goal<away_team_goal and away_team regexp "bayern") or 
(away_team regexp "dortmund" and away_team_goal<home_team_goal and home_team regexp "bayern")


# which team has most wins in German championship from 2008 to 2016?

select home_team as team, home_wins,away_wins,home_wins+away_wins as wins_total 
from
(with home as 
(select mv.*,
case
when home_team_goal>away_team_goal then "home win"
when home_team_goal=away_team_goal then "home draw"
when home_team_goal<away_team_goal then "home lose"
end as status
from matches_view mv
where country ="germany")
select home_team,count(status) as home_wins
from home 
where status="home win"
group by home_team) as a 
join
(with away as 
(select mv.*,
case
when away_team_goal>home_team_goal then "away win"
when away_team_goal=home_team_goal then "away draw"
when away_team_goal<home_team_goal then "away lose"
end as status
from matches_view mv
where country ="germany")
select away_team,count(status) as away_wins
from away 
where status="away win"
group by away_team) as b
on a.home_team=b.away_team
order by wins_total desc	


# create view of matches and team attributes
drop view if exists view_tactics;
create view view_tactics as 
select m.id as match_id,
c.name as country,
l.name as league,
m.season as season,
date(m.date) as date,
date(ta1.date) as ta_date,
t1.team_long_name as home_team,
m.home_team_goal,
m.away_team_goal,
t2.team_long_name as away_team,
m.home_team_api_id,
m.away_team_api_id,
ta1.buildUpPlaySpeed as h_buildUpPlaySpeed,
ta1.buildUpPlaySpeedClass as h_buildUpPlaySpeedClass,
ta1.buildUpPlayDribbling as h_buildUpPlayDribbling,
ta1.buildUpPlayDribblingClass as h_buildUpPlayDribblingClass,
ta1.buildUpPlayPassing as h_buildUpPlayPassing,
ta1.buildUpPlayPassingClass as h_buildUpPlayPassingClass,
ta1.buildUpPlayPositioningClass as h_buildUpPlayPositioningClass,
ta1.chanceCreationPassing as h_chanceCreationPassing,
ta1.chanceCreationPassingClass as h_chanceCreationPassingClass,
ta1.chanceCreationCrossing as h_chanceCreationCrossing,
ta1.chanceCreationCrossingClass as h_chanceCreationCrossingClass,
ta1.chanceCreationShooting as h_chanceCreationShooting,
ta1.chanceCreationShootingClass as h_chanceCreationShootingClass,
ta1.chanceCreationPositioningClass as h_chanceCreationPositioningClass,
ta1.defencePressure as h_defencePressure,
ta1.defencePressureClass as h_defencePressureClass,
ta1.defenceAggression as h_defenceAggression,
ta1.defenceAggressionClass as h_defenceAggressionClass,
ta1.defenceTeamWidth as h_defenceTeamWidth,
ta1.defenceTeamWidthClass as h_defenceTeamWidthClass,
ta1.defenceDefenderLineClass as h_defenceDefenderLineClass,
ta2.buildUpPlaySpeed as a_buildUpPlaySpeed,
ta2.buildUpPlaySpeedClass as a_buildUpPlaySpeedClass,
ta2.buildUpPlayDribbling as a_buildUpPlayDribbling,
ta2.buildUpPlayDribblingClass as a_buildUpPlayDribblingClass,
ta2.buildUpPlayPassing as a_buildUpPlayPassing,
ta2.buildUpPlayPassingClass as a_buildUpPlayPassingClass,
ta2.buildUpPlayPositioningClass as a_buildUpPlayPositioningClass,
ta2.chanceCreationPassing as a_chanceCreationPassing,
ta2.chanceCreationPassingClass as a_chanceCreationPassingClass,
ta2.chanceCreationCrossing as a_chanceCreationCrossing,
ta2.chanceCreationCrossingClass as a_chanceCreationCrossingClass,
ta2.chanceCreationShooting as a_chanceCreationShooting,
ta2.chanceCreationShootingClass as a_chanceCreationShootingClass,
ta2.chanceCreationPositioningClass as a_chanceCreationPositioningClass,
ta2.defencePressure as a_defencePressure,
ta2.defencePressureClass as a_defencePressureClass,
ta2.defenceAggression as a_defenceAggression,
ta2.defenceAggressionClass as a_defenceAggressionClass,
ta2.defenceTeamWidth as a_defenceTeamWidth,
ta2.defenceTeamWidthClass as a_defenceTeamWidthClass,
ta2.defenceDefenderLineClass as a_defenceDefenderLineClass
from matches m
join country c on c.id=m.country_id
join team t1 on t1.team_api_id=m.home_team_api_id
join team t2 on t2.team_api_id=m.away_team_api_id
join league l on l.country_id=m.country_id
left join team_attributes ta1 on ta1.team_api_id=m.home_team_api_id and year(ta1.date)=year(m.date)
left join team_attributes ta2 on ta2.team_api_id=m.away_team_api_id and year(ta2.date)=year(m.date)


#for every team find average goals scored in a match for 2012/2013 season. sort by average goals scored.

select t1.season as season, home_team as team, avg_home_scored,avg_away_scored,(avg_home_scored+avg_away_scored)/2 as scored
from
(select season,home_team, avg(home_team_goal) as avg_home_scored
from matches_view
group by season, home_team) as t1
join
(select season,away_team, avg(away_team_goal) as avg_away_scored
from matches_view
group by season, away_team) as t2
on t1.home_team=t2.away_team and t1.season=t2.season
where t1.season="2012/2013"
order by season asc,scored desc


# for every season find top 3 championships with the most avg goal per match

with a as
(select season, league, avg(home_team_goal+away_team_goal) as avg_goal,
row_number() over (partition by season order by avg(home_team_goal+away_team_goal) desc ) as col
from matches_view
group by season,league
order by season, avg_goal desc)
select *
from a 
where col<=3

#for every league find top 3 matchdays with the most scored goals

with a as
(select league,date, sum(home_team_goal+away_team_goal) as goals,
row_number() over (partition by league order by sum(home_team_goal+away_team_goal) desc) as top 
from matches_view
group by league,date
order by league, goals desc)
select *
from a 
where top<=3



# find teams that has won more than 80% of matches in a season
select home.season as season, home_team as team, home_wins+away_wins as wins, home_matches+away_matches as matches,
round((home_wins+away_wins)/(home_matches+away_matches)*100,2) as win_percentage
from
(select season, home_team, count(home_team) as home_matches,
count(if(home_team_goal>away_team_goal,home_team,null)) as home_wins
from matches_view mv
group by season, home_team) as home
join
(select season, away_team, count(away_team) as away_matches,
count(if(away_team_goal>home_team_goal,away_team,null)) as away_wins
from matches_view mv
group by season, away_team) as away
on home.season=away.season and home.home_team=away.away_team
having win_percentage>80
order by season, win_percentage desc

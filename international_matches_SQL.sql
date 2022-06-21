# number of matches per year
select year(date) as year, count(home_team) as count_of_matches
from results
group by year
order by year

# find teams with the most matches played

select home_team as team, home_matches, away_matches, home_matches+away_matches as matches
from
(select home_team, count(home_team) as home_matches
from results
group by home_team) as home
join
(select away_team, count(away_team) as away_matches
from results
group by away_team) as away
on home.home_team=away.away_team
order by matches desc

# find teams that have played the most matches on World Cup

select home_team as team, home_matches, away_matches, home_matches+away_matches as matches
from
(select home_team, count(home_team) as home_matches
from results
where tournament="FIFA World Cup"
group by home_team) as home
join
(select away_team, count(away_team) as away_matches
from results
where tournament="FIFA World Cup"
group by away_team) as away
on home.home_team=away.away_team
order by matches desc


# Which countires and how many times have hosted international matches during WW2

select country, count(country) as timeshosted
from results
where date between "1939-09-01" and "1945-09-02"
group by country
order by timeshosted desc

# Which team has the highest win percentage in international matches having they have played more than 100 matches

select home_team as team, home_matches+away_matches as matches, home_wins+away_wins as wins,
round((home_wins+away_wins)/(home_matches+away_matches)*100,1) as win_percentage
from 
(select home_team, count(home_team) as home_matches, count(if(home_score>away_score,home_team,null)) as home_wins
from results
group by home_team) as home
join
(select away_team, count(away_team) as away_matches, count(if(away_score>home_score,away_team,null)) as away_wins
from results
group by away_team) as away
on home_team=away_team
having  matches >100
order by win_percentage desc


# Which team has the highest win percentage in penalties, on condition that they have played more than 5

select home_team as team, home_matches+away_matches as matches, home_wins+away_wins as wins,
round((home_wins+away_wins)/(home_matches+away_matches)*100,1) as win_percentage
from
(select home_team, count(home_team) as home_matches, count(if(home_team=winner, winner,Null)) as home_wins
from results
join shootouts using(date,home_team,away_team)
group by home_team) as home
join
(select away_team, count(away_team) as away_matches, count(if(away_team=winner, winner,Null)) as away_wins
from results
join shootouts using(date,home_team,away_team)
group by away_team) as away
on home_team=away_team
having matches>5
order by win_percentage desc, team asc


# Longest consecutive home win chain for every team

with b as 
(with a as 
(select date, home_team, home_score,away_score,row_number() over(order by home_team, date) as rn
from results) 
select a.*, lag(rn) over() as previous_rn
from a 
where home_score<=away_score)
select b.*, max(rn-previous_rn-1) as win_chain
from b
group by home_team
order by win_chain desc

# which team scores most goals per match, which accepts least, which team has the highest score/accept ratio?

select home_team as team, (home_scored+away_scored)/2 as scored, (home_accepted+away_accepted)/2 as accepted,
round((home_scored+away_scored)/(home_accepted+away_accepted),2) as `score/acc`
from 
(select home_team, avg(home_score) as home_scored, avg(away_score) as home_accepted
from results
group by home_team) as home 
join
(select away_team, avg(away_score) as away_scored, avg(home_score) as away_accepted
from results
group by away_team) as away 
on home_team=away_team
order by `score/acc` desc

# which team has the highest win percentage against which team. Create procedure to find win percentage between two teams
 
delimiter $$
drop procedure if exists procedure_rivals;
create procedure procedure_rivals(p_winner_team varchar(55), p_loser_team varchar(55))
begin
	select home.home_team as winner_team, home.away_team as loser_team, (home_matches_against+away_matches_against) as matches, (home_wins+away_wins) as wins,
	round((home_wins+away_wins)/(home_matches_against+away_matches_against)*100,1) as win_percentage
	from
	(select home_team, away_team, count(home_team) as home_matches_against, count(if(home_score>away_score,home_team,null)) as home_wins
	from results
	group by home_team, away_team) as home
	join
	(select away_team, home_team, count(away_team) as away_matches_against, count(if(home_score<away_score,away_team,null)) as away_wins
	from results
	group by away_team, home_team) as away
	on home.home_team=away.away_team and home.away_team=away.home_team
	where (home.home_team=ifnull(p_winner_team,home.home_team) and home.away_team=ifnull(p_loser_team,home.away_team)) 
	or    (home.home_team=ifnull(p_loser_team,home.home_team) and home.away_team=ifnull(p_winner_team,home.away_team));
end $$
delimiter ;

call procedure_rivals("Germany", "Portugal")


# create procedure to get win percentage for each team by year

delimiter $$
drop procedure if exists procedure_win_percentage_by_year;
create procedure procedure_win_percentage_by_year(p_team varchar(55))
begin
	select home.year as year, home_team as team, ifnull(home_matches,0)+ifnull(away_matches,0) as matches, ifnull(home_wins,0)+ifnull(away_wins,0) as wins,
	round((ifnull(home_wins,0)+ifnull(away_wins,0))/(ifnull(home_matches,0)+ifnull(away_matches,0))*100,1) as win_percentage
	from
	(select year(date) as year, home_team, count(home_team) as home_matches, count(if(home_score>away_score,home_team,null)) as home_wins
	from results
	group by year(date), home_team) as home
	left outer join
	(select year(date) as year, away_team, count(away_team) as away_matches, count(if(away_score>away_score,home_team,null)) as away_wins
	from results
	group by year(date), away_team) as away
	on home.home_team=away.away_team and home.year=away.year
	having team=ifnull(p_team, team)
	order by year, team;
end $$

call procedure_win_percentage_by_year("Georgia")

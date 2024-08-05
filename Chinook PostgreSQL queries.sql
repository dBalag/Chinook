Chinook PostgreSQL queries


--Total Sales per Employee, CTE

with a as (select c.customer_id, c.first_name, c.last_name, sum (i.total) sales, c.support_rep_id
           from customer c join invoice i using (customer_id)
          	group by c.customer_id, c.first_name, c.last_name, c.support_rep_id ),
            
     b as (select e.employee_id, e.first_name, e.last_name, sum(a.sales) sales
           from employee e join a a on employee_id=support_rep_id
           group by e.employee_id, e.first_name, e.last_name, a.sales)
           
 select employee_id, first_name, last_name, sales 
 from b 
 group by employee_id, first_name, last_name, sales
 order by sales desc;


--Top 5 Genres by Track Count, subquery

select g.genre_id, g.name, txg.total tracks 
from genre g
join (select genre_id, count (track_id) total 
        from track group by genre_id) as txg
on g.genre_id=txg.genre_id
group by g.genre_id, g.name, tracks
order by tracks desc limit 5;

--Customer Ranking by Total Spending, rank

select customer_id, first_name, last_name, rank () over (order by spended desc) as rank, spended

from (select i.customer_id, c.first_name, c.last_name, sum (total) spended
      from invoice i join customer c using (customer_id)
	  group by i.customer_id, c.first_name, c.last_name) as customer_spend

group by customer_id, first_name, last_name, spended;


--Tracks in Multiple Playlists, subquery 

select t.track_id, t.name, count (pt.playlist_id) playlists
from track t join playlist_track pt using (track_id)
group by t.track_id, t.name order by playlists desc;


--Monthly Sales Trend, datepart

select extract(year from invoice_date) as year, extract(month from invoice_date) as month, sum (total) revenues
from invoice 
group by year, month
order by year, month asc ;


--Total Sales by Genre: Write a query to find the total number of tracks sold per genre.

select g.name, sum (il.quantity) as nr_tracks, sum (il.quantity * il.unit_price) as revenues
from track t join invoice_line il using (track_id)
			 join genre g using (genre_id)
group by g.name
order by revenues desc;

--Customer Purchase History: Create a query that lists customers along with their most recent purchase date.

select customer_id, first_name, last_name, extract (year from invoice_date) as year,
        extract (month from invoice_date) as month, extract (day from invoice_date) as day
from (select c.customer_id, c.first_name, c.last_name, i.invoice_date,
      row_number () over (partition by c.customer_id order by i.invoice_date desc) as rn
	  from invoice i join customer c using (customer_id) ) as sub
where rn=1
order by invoice_date desc;


--Top Earning Employees: Construct a query that shows the top 5 highest earning employees based on sales.

with a as (select c.customer_id, c.first_name, c.last_name, sum (i.total) sales, c.support_rep_id
           from customer c join invoice i using (customer_id)
          	group by c.customer_id, c.first_name, c.last_name, c.support_rep_id ),
            
     b as (select e.employee_id, e.first_name, e.last_name, sum(a.sales) sales
           from employee e join a a on employee_id=support_rep_id
           group by e.employee_id, e.first_name, e.last_name, a.sales)
           
 select employee_id, first_name, last_name, sales 
 from b 
 group by employee_id, first_name, last_name, sales
 order by sales desc;

--Customer Distribution by Country: Develop a query that identifies which countries have the highest number of customers.

select country, count (customer_id) nr_customers
from customer
group by country
order by nr_customers desc limit 5;

--Annual Revenue: Formulate a query that calculates the total revenue from sales per year.

select extract(year from invoice_date) as year, sum (total) total_revs
from invoice
group by year
order by total_revs desc;


--Top Selling Tracks and Albums: Write a query to find the top 10 selling tracks and albums.

with a as (select t.name track_name, sum(il.unit_price * il.quantity) as tracks_revs
           from invoice_line il join track t using (track_id)
           group by track_name order by tracks_revs desc limit 10),
           
     b as (select a.title album_name, sum (il.unit_price * il.quantity) as albums_revs
           from track t join invoice_line il using (track_id)
           				join album a using (album_id)
           group by album_name order by albums_revs desc limit 10)
  
select 'track' as type, track_name as name , tracks_revs as revs from a union all 
select 'album' as type, album_name as name, albums_revs as revs from b
order by revs desc ;
  

--Customer Spending by Country: Construct a query to analyze how customer spending varies across different countries.

with a as (select billing_country as country, sum(total) as billed
           from invoice group by billing_country)

select country, billed 	/* sum total x country is already the avg*/
from a 
order by billed desc;


--Seasonal Sales Trends: Formulate a query to identify any seasonal trends or patterns in sales.

select extract (month from invoice_date) as month, sum (total) total_rev
from invoice
group by month
order by total_rev desc


/*Count the number of tracks sold grouped by genre name. Then compare the average of these numbers 
to the median. How do they compare? This question is required.*/


with comp as (select g.name, count (il.track_id) tracks_sold 
              from track t join invoice_line il using (track_id)
						     join genre g using (genre_id)
              group by g.name)             

select  avg(tracks_sold) avg_tracks,  (select PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tracks_sold) AS median from comp) as median
from comp;


/*Which artist/composer combination have the most number of tracks together? Do not ignore cases with NULL 
composer. When composer is null, overwrite the null value with the artist associated with the track.*/

select coalesce(t.composer, a.name) , a.name, count(distinct t.track_id) total 
from album ab   join artist a using (artist_id)
                join track t using(album_id) 
group by t.composer, a.name order by total desc;


/*How much more revenue is the employee with the most sales responsible for compared to the employee 
with the least sales? Answer in percentage terms*/

with a as (select e.employee_id, sum(i.total) sales 
           from customer c 
            join employee e on e.employee_id=c.support_rep_id
            join invoice i using (customer_id) 
          group by e.employee_id order by sales desc)

select round((max (sales) - min(sales))*100/min(sales)) from a;


/*In what year-month's (YYYY-MM) was total revenue at Chinook greater than it was in the previous 
month by at least 40%?*/

with    a as (select  to_char(invoice_date, 'YYYY-MM') as date, sum (total) rev
			 from invoice group by date),

        b as (sELECT date, rev, LAG(rev) OVER (ORDER BY to_date(date, 'YYYY-MM')) AS prev
    		  FROM a)

select date, rev, prev, ROUND(((rev - prev)*100 / prev), 0) AS growth_percentage
FROM b
WHERE round(((rev - prev)*100 / prev), 0) >= 40 


/*Every year Chinook employees compete to see who can bring in the most revenue. Who has won this 
competition the most times?*/

with a as (select to_char(i.invoice_date, 'YYYY') as year, sum (i.total) total, e.first_name as name
			from customer c join invoice i using (customer_id)
							join employee e on c.support_rep_id=e.employee_id
			group by year, e.first_name),

    b as (SELECT year, name, total, RANK() OVER (PARTITION BY year ORDER BY total DESC) AS rank
    	FROM a)

SELECT year, name, total 
FROM b
WHERE rank = 1 ORDER BY year;


/*What percentage growth did the Metal genre experience in terms of number of tracks sold between 2023 
and 2024?*/

with a as (select to_char(i.invoice_date, 'YYYY') as year, g.name, count(il.track_id) tracks
           from track t join genre g using (genre_id)
           				join invoice_line il using (track_id)
           				join invoice i using (invoice_id)
           where to_char(i.invoice_date, 'YYYY')='2023' and g.name='Metal' 
           group by to_char(i.invoice_date, 'YYYY'), g.name),

    b as (select to_char(i.invoice_date, 'YYYY') as year, g.name, count(il.track_id) tracks
           from track t join genre g using (genre_id)
           				join invoice_line il using (track_id)
           				join invoice i using (invoice_id)
           where to_char(i.invoice_date, 'YYYY')='2024' and g.name='Metal' 
           group by to_char(i.invoice_date, 'YYYY'), g.name)
  
  select round(((b.tracks-a.tracks)/a.tracks::numeric),2) 
  from a,b;


/*Amongst Genre's that sold at least 10 tracks in 2023, which one experienced the greatest decrease in 
sales from the previous year?*/

with a as (select to_char(i.invoice_date, 'YYYY') as year, g.name as genre_name, count (il.track_id) tracks
           from track t join genre g using (genre_id)
           				join invoice_line il using (track_id)
           				join invoice i using (invoice_id)
           where to_char(i.invoice_date, 'YYYY')='2023' 
           group by to_char(i.invoice_date, 'YYYY'), genre_name
          	having count (il.track_id) >=10),

    b as (select to_char(i.invoice_date, 'YYYY') as year, g.name as genre_name, count (il.track_id) tracks
           from track t join genre g using (genre_id)
           				join invoice_line il using (track_id)
           				join invoice i using (invoice_id)
           where to_char(i.invoice_date, 'YYYY')='2022' 
           group by to_char(i.invoice_date, 'YYYY'), genre_name)

select a.genre_name, (a.tracks-b.tracks)::numeric as diff 
from a JOIN b ON a.genre_name = b.genre_name 
order by diff asc limit 1;


/*Consider a customer "loyal" if their average invoice total in the last 6 months exceeds their average 
 invoice total prior to the last 6 months. Suppose that the current date is 2024-05-07. How many customers 
 are loyal? This question is required.*/   
    
WITH invoice_data AS    (SELECT customer_id, to_char(invoice_date, 'YYYY-MM-DD') as invoice_date, total,
                            CASE WHEN invoice_date >= '2023-11-07' THEN 'last_6_months'
                            ELSE 'prior_6_months'
                            END AS period
                        FROM invoice
                        WHERE invoice_date >= '2023-05-07'),

customer_averages AS (SELECT customer_id, period, AVG(total) AS avg_total
                      FROM invoice_data
                      GROUP BY customer_id, period),

loyal_customers AS (SELECT customer_id
                    FROM customer_averages
                    GROUP BY customer_id
                    HAVING  MAX(CASE WHEN period = 'last_6_months' THEN avg_total ELSE NULL END) > 
                            MAX(CASE WHEN period = 'prior_6_months' THEN avg_total ELSE NULL END))

SELECT COUNT(*)
FROM loyal_customers;

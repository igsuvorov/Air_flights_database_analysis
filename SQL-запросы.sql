
	1	В каких городах больше одного аэропорта?
 
Сначала из таблицы airports выведем количество записей в столбце city;
Затем добавим условие, что количество записей должно быть больше 1

select
	city,
	count(city)
from
	airports
group by
	1
having
	count(city) > 1





2   В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

Выведем aircraft_code из таблицы aircrafts;
Добавим сортировку по столбцу "range" в обратном порядке и оставим только первую строку;
Выведем информацию об уникальных аэропортах отправления (departure_airport) из таблицы flights;
И добавим ограничение, что код самолета (aircraft_code) должен быть равен значению, 
полученному нами во втором запросе (заворачиваем его в подзапрос)

select
	distinct departure_airport
from
	flights
where
	aircraft_code = (
	select
		aircraft_code
	from
		aircrafts
	order by
		"range" desc
	limit 1)






3     Вывести 10 рейсов с максимальным временем задержки вылета

Выведем время вылета по расписанию (scheduled_departure);
фактическое время вылета (actual_departure),
а также разницу между факстическим временем вылета и временем вылета по расписанию из таблицы flights;
Зададим ограничение, что разница не должна быть равна нулю;
Затем сортируем наш запрос по 3 пункту (разница) в обратном порядке и задаем ограничение на 10 первых записей

select
	scheduled_departure,
	actual_departure,
	actual_departure - scheduled_departure as Delay
from
	flights
where
	actual_departure - scheduled_departure is not null
order by
	3 desc
limit 10


4     Были ли брони, по которым не были получены посадочные талоны?

Выведем номер бронирования (book_ref) из таблицы bookings;
Затем нам нужно присоединить таблицу boarding_passes к таблице bookings,
но напрямую мы этого сделать не можем, 
поэтому сначала присоединяем таблицу tickets по условию, что таблицы tickets и bookings имеют общий знаменатель book_ref,
одновременно выводим в результат запроса номер билета (ticket_no);
Уже затем присоединяем таблицу boarding_passes по условию, 
что таблицы boarding_passes и tickets имеют общий знаменатель ticket_no,
одновременно выводим в результат запроса номер бронирования (boarding_no);
Затем нам нужно добавить ограничение того, что бронирования (boarding_no) должен быть равен нулю,
ведь по условию задания посадочные талоны не были получены

select
	b.book_ref,
	t.ticket_no,
	boarding_no
from
	bookings b
join tickets t on
	t.book_ref = b.book_ref
left join boarding_passes bp on
	bp.ticket_no = t.ticket_no
where
	boarding_no is null

В результате этого запроса мы видим, что были бронирования, 
по которым не было получено посадочных талонов



5	Найдите количество свободных мест для каждого рейса, 
их % отношение к общему количеству мест в самолете. 
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных 
пассажиров из каждого аэропорта на каждый день. 
Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек 
уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня

 * CTE boarded получает количество выданных посадочных талонов по каждому рейсу
 * Ограничение actual_departure is not null для того, чтобы отслеживать уже вылетевшие рейсы
 * CTE max_seats_by_aircraft получает количество мест в самолёте
 * В итоговом запросе оба CTE джойнятся по aircraft_code
 * Для подсчета накопительной суммы использется оконная функция c разделением по аэропорту отправления и времени вылета приведенному к формату date. 
 */
with boarded as (
	select 
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.scheduled_departure,
		f.actual_departure,
		count(bp.boarding_no) boarded_count
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	where f.actual_departure is not null
	group by f.flight_id 
),
max_seats_by_aircraft as(
	select 
		s.aircraft_code,
		count(s.seat_no) max_seats
	from seats s 
	group by s.aircraft_code 
)
select 
	b.flight_no,
	b.departure_airport,
	b.scheduled_departure,
	b.actual_departure,
	b.boarded_count,
	m.max_seats - b.boarded_count free_seats, 
	round((m.max_seats - b.boarded_count) / m.max_seats :: dec, 2) * 100 free_seats_percent,
	sum(b.boarded_count) over (partition by (b.departure_airport, b.actual_departure::date) order by b.actual_departure) "Накопительно пассажиров"
from boarded b 
join max_seats_by_aircraft m on m.aircraft_code = b.aircraft_code


6	Найдите процентное соотношение перелетов по типам самолетов от общего количества

Выведем всю интересующую нас информацию: модель самолета,  количество рейсов, 
процентное соотношение рейсов, совершенных каждым самолетом.
Процентное соотношение найдем, разделив общее количество рейсов на количество фактически совершенных рейсов, используя оператор round
Добавим ограничение, которое посчитает результат только по совершенным рейсам

select
	a.model,
	count(f.flight_id),
	round(count(f.flight_id) /
(select 
count(f.flight_id)
from flights f
where f.actual_departure is not null)::dec * 100, 4)
from
	flights f
join aircrafts a on
	a.aircraft_code = f.aircraft_code
where
	f.actual_departure is not null
group by
	1




7	Были ли города, в которые можно добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

Формируем cte, в котором выведем информацию о городах вылета и прибытия, а также класс обслуживания. 
С помощью оператора case выведем максимальную сумму для эконом-класса и минимальную для бизнес-класса.
Из нашей cte выведем информацию о городах вылета и прибытия, максимальную сумму за эконом класс и минимальную сумму за бизнесс-класс.
Зададим условие что максимальная сумма за эконом-класс должна быть больше минимальной за бизнес-класс

select
	a.city as departure_city,
	a2.city as arrival_city,
	tf.fare_conditions as "class",
	case
		when tf.fare_conditions = 'Economy' then max(tf.amount) 
	end max_economy,
	case
		when tf.fare_conditions = 'Business' then min(tf.amount) 
	end min_business
from
	flights f
join airports a on
	a.airport_code = f.departure_airport
join airports a2 on
	a2.airport_code = f.arrival_airport
join ticket_flights tf on
	tf.flight_id = f.flight_id
group by
	1,
	2,
	3
 
 with cte as (
	select
		a.city as departure_city,
		a2.city as arrival_city,
		tf.fare_conditions as "class",
		case
			when tf.fare_conditions = 'Economy' then max(tf.amount)
		end max_economy,
		case
			when tf.fare_conditions = 'Business' then min(tf.amount)
		end min_business
	from
		flights f
	join airports a on
		a.airport_code = f.departure_airport
	join airports a2 on
		a2.airport_code = f.arrival_airport
	join ticket_flights tf on
		tf.flight_id = f.flight_id
	group by
		1,
		2,
		3)
 select
	departure_city,
	arrival_city,
	max_economy,
	min_business
from
	cte
group by
	1,
	2,
	3,
	4
having
	max_economy > min_business
 
 
 


8	Между какими городами нет прямых рейсов?


Выводим город отправления из таблицы airports, присоединяя таблицу airports к таблице flights по условию,
что код аэропорта из таблицы airports 
равен коду аэропорта отправления из таблицы flights;
Еще раз присоединяем таблицу a2.airports по условию, что код аэропорта из таблицы a2.airports 
равен коду аэропорта прибытия из таблицы flights, затем выводим город прибытия из таблицы a2.airports;
Создаем из этого запроса представление
 
create view true_flight as
  select
	distinct 
a.city as departure_city,
	a2.city as arrival_city
from
	flights f
join airports a on
	a.airport_code = f.departure_airport
join airports a2 on
	a2.airport_code = f.arrival_airport
 
Выведем декарторво произведение всех городов

select
	distinct 
a.city as departure_city,
	a2.city as arrival_city
from
	airports a,
	airports a2

С помощью except удалим из получившегося запроса данные о городах, между которыми есть прямые рейсы

select
	distinct 
a.city as departure_city,
	a2.city as arrival_city
from
	airports a,
	airports a2
	where a.city != a2.city
except
select
	*
from
	true_flight



9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
	сравните с допустимой максимальной дальностью перелетов в самолетах, обслуживающих эти рейс*	
	Оператор RADIANS или использование sind/cosd; case
	
		
	Выведем нужную нам информацию, присоединяя нужные таблицы
	Посчитаем расстояние между аэропортами с помощью формулы L = d·R, где R = 6371 км — средний радиус земного шара,
	d = arccos {sin(latitude_a)·sin(latitude_b) + cos(latitude_a)·cos(latitude_b)·cos(longitude_a - longitude_b)}, 
	где latitude_a и latitude_b — широты, longitude_a, longitude_b — долготы данных пунктов
	С помощью оператора case сравним максимальное расстояние, которое может преодолеть самолет,
	с расстоянием между аэропортами и выведем информацию о возможности или невозможности полета	
	
select
	distinct
	a.airport_name as air_dep,
	a2.airport_name as air_arr,
	a3."range",
	acos(sind(a.latitude)* sind(a2.latitude) + cosd(a.latitude)* cosd(a2.latitude)* cosd(a.longitude - a2.longitude)) * 6371 as "Расстояние",
	case
		when
a3."range" > 
acos(sind(a.latitude)* sind(a2.latitude) + cosd(a.latitude)* cosd(a2.latitude)* cosd(a.longitude - a2.longitude)) * 6371
then 'Полет возможен'
		else 'Полет невозможен'
	end
from
	flights f
join airports a on
	a.airport_code = f.departure_airport
join airports a2 on
	a2.airport_code = f.arrival_airport
join aircrafts a3 on
	a3.aircraft_code = f.aircraft_code
	
	


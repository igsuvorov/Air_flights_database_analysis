# Air flights database analysis

Полный анализ демонстрационной базы данных для СУБД PostgreSQL. В этом документе
описана схема данных, состоящая из восьми таблиц и нескольких представлений. В качестве
предметной области выбраны авиаперевозки по России

Задача: с помощью данных отыскать способы сокращения издержек авиакомпании

Результаты: выявил множество способов оптимизации авиаперелетов, тем самым уменьшив расходы авиакомпании

![Безымянный](https://user-images.githubusercontent.com/124151898/218076914-8908190b-d7d8-49ce-9031-f644b71b93c7.png)

Если нужно описание базы данных в виде отдельных файлов, то они находятся внутри репозитория

1.	**Краткое описание базы данных (таблицы и представления):**

*Таблицы:*
1)	Aircrafts – код самолета, модель самолета, максимальная дальность полета(км)
2)	Airports – код аэропорта, название аэропорта, город, координаты города (широта, долгота), временная зона аэропорта
3)	Boarding_passes – номер билета, идентификатор рейса, номер посадочного талона, номер места
4)	Bookings – номер бронирования, дата бронирования, полная сумма бронирования
5)	Flights – идентификатор рейса, номер рейса, время вылета по расписанию, время прилета по расписанию, аэропорт отправления, аэропорт прибытия, статус рейса, код самолета, фактическое время вылета, фактическое время прилета
6)	Seats – код самолета, номер места, класс обслуживания
7)	Ticket_flights – номер билета, идентификатор рейса, класс обслуживания, стоимость перелета
8)	Tickets – номер билета, номер бронирования, идентификатор пассажира, имя пассажира, контактные данные пассажира

*Представления:*
1)	Bookings.flights_v - идентификатор рейса, номер рейса, время вылета по расписанию + местное, время прилета по расписанию + местное, планируемая продолжительность полета, код аэропорта отправления, название аэропорта отправления, город отправления, код аэропорта прибытия, название аэропорта прибытия, город прибытия, статус рейса, код самолета, фактическое время вылета + местное, фактическое время прилета + местное, фактическая продолжительность полета
2)	Routes – материализованное представление. Номер рейса, код аэропорта отправления, название аэропорта отправления, город отправления, код аэропорта прибытия, название аэропорта прибытия, город прибытия, код самолёта, продолжительность полета, дни недели, когда выполняется рейс


2.	**Развернутый анализ базы данных - описание таблиц, логики, связей и бизнес-области**
1)	Aircrafts:
- Каждая модель воздушного судна идентифицируется своим трехзначным кодом (aircraft_code). Указывается также название модели (model) и максимальная дальность полета в километрах (range)
- Индексы: PRIMARY KEY, btree (aircraft_code) 
- Ограничения-проверки: CHECK (range > 0) 
- Ссылки извне: TABLE "flights" FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) TABLE "seats" FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) ON DELETE CASCADE
2)	Airports:
- Аэропорт идентифицируется трехбуквенным кодом (airport_code) и имеет свое имя (airport_name). Для города не предусмотрено отдельной сущности, но название (city) указывается и может служить для того, чтобы определить аэропорты одного города. Также указывается широта (longitude), долгота (latitude) и часовой пояс (timezone)
- Индексы: PRIMARY KEY, btree (airport_code) 
- Ссылки извне: TABLE "flights" FOREIGN KEY (arrival_airport) REFERENCES airports(airport_code) TABLE "flights" FOREIGN KEY (departure_airp
3)	Boarding_passes:
- При регистрации на рейс, которая возможна за сутки до плановой даты отправления, пассажиру выдается посадочный талон. Он идентифицируется также, как и перелет — номером билета и номером рейса. Посадочным талонам присваиваются последовательные номера (boarding_no) в порядке регистрации пассажиров на рейс (этот номер будет уникальным только в пределах данного рейса). В посадочном талоне указывается номер места (seat_no)
- Индексы: PRIMARY KEY, btree (ticket_no, flight_id) UNIQUE CONSTRAINT, btree (flight_id, boarding_no) UNIQUE CONSTRAINT, btree (flight_id, seat_no) 
- Ограничения внешнего ключа: FOREIGN KEY (ticket_no, flight_id) REFERENCES ticket_flights(ticket_no, flight_id)
4)	Bookings:
- Пассажир заранее (book_date, максимум за месяц до рейса) бронирует билет себе и, возможно, нескольким другим пассажирам. Бронирование идентифицируется номером (book_ref, шестизначная комбинация букв и цифр). Поле total_amount хранит общую стоимость включенных в бронирование перелетов всех пассажиров
- Индексы: PRIMARY KEY, btree (book_ref) 
- Ссылки извне: TABLE "tickets" FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)
5)	Flights:
- Естественный ключ таблицы рейсов состоит из двух полей — номера рейса (flight_no) и даты отправления (scheduled_departure). Чтобы сделать внешние ключи на эту таблицу компактнее, в качестве первичного используется суррогатный ключ (flight_id). Рейс всегда соединяет две точки — аэропорты вылета (departure_airport) и прибытия (arrival_airport). Такое понятие, как «рейс с пересадками» отсутствует: если из одного аэропорта до другого нет прямого рейса, в билет просто включаются несколько необходимых рейсов. У каждого рейса есть запланированные дата и время вылета (scheduled_departure) и прибытия (scheduled_arrival). Реальные время вылета (actual_departure) и прибытия (actual_arrival) могут отличаться: обычно не сильно, но иногда и на несколько часов, если рейс задержан
- Индексы: PRIMARY KEY, btree (flight_id) UNIQUE CONSTRAINT, btree (flight_no, scheduled_departure) 
- Ограничения-проверки: CHECK (scheduled_arrival > scheduled_departure) CHECK ((actual_arrival IS NULL) OR ((actual_departure IS NOT NULL AND actual_arrival IS NOT NULL) AND (actual_arrival > actual_departure))) CHECK (status IN ('On Time', 'Delayed', 'Departed', 'Arrived', 'Scheduled', 'Cancelled')) 
- Ограничения внешнего ключа: FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) FOREIGN KEY (arrival_airport) REFERENCES airports(airport_code) FOREIGN KEY (departure_airport) REFERENCES airports(airport_code) 
- Ссылки извне: TABLE "ticket_flights" FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
6)	Seats:
- Места определяют схему салона каждой модели. Каждое место определяется своим номером (seat_no) и имеет закрепленный за ним класс обслуживания (fare_conditions) — Economy, Comfort или Business
- Индексы: PRIMARY KEY, btree (aircraft_code, seat_no) 
- Ограничения-проверки: CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business'))
- Ограничения внешнего ключа: FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) ON DELETE CASCADE
7)	Ticket_flights:
- Перелет соединяет билет с рейсом и идентифицируется их номерами. Для каждого перелета указываются его стоимость (amount) и класс обслуживания (fare_conditions)
- Индексы: PRIMARY KEY, btree (ticket_no, flight_id) 
- Ограничения-проверки: CHECK (amount >= 0) CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business')) 
- Ограничения внешнего ключа: FOREIGN KEY (flight_id) REFERENCES flights(flight_id) FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no) 
- Ссылки извне: TABLE "boarding_passes" FOREIGN KEY (ticket_no, flight_id) REFERENCES ticket_flights(ticket_no, flight_id)
8)	Tickets:
- Билет имеет уникальный номер (ticket_no), состоящий из 13 цифр. Билет содержит идентификатор пассажира (passenger_id) — номер документа, удостоверяющего личность, — его фамилию и имя (passenger_name) и контактную информацию (contact_date). Ни идентификатор пассажира, ни имя не являются постоянными (можно поменять паспорт, можно сменить фамилию), поэтому однозначно найти все билеты одного и того же пассажира невозможно
- Индексы: PRIMARY KEY, btree (ticket_no) 
- Ограничения внешнего ключа: FOREIGN KEY (book_ref) REFERENCES bookings(book_ref) 
- Ссылки извне: TABLE "ticket_flights" FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no)


***Бизнес задачи, которые можно решить, используя данную базу данных:***

1)	С помощью данной базы данных можно провести множество видов анализа маршрутов по различным признакам: по цене, по классу обслуживания, по расстоянию, по возможности прямого перелета, по времени отправления (в т. ч. по дате и дням недели) и т.д.

2)	Изучение информации о задержках или отменах рейсов

3)	Возможность создания новых маршрутов, если между какими-либо городами нет прямых рейсов, а также целесообразность создания таких маршрутов

4)	Изучение количества рейсов на предмет отказа пассажиров от билетов, а также количества незаполненных мест в самолете, возможно нахождение закономерностей для количества свободных мест

5)	 Получение данных для возврата денег за неиспользованные билеты.

6)	Сравнение цен в зависимости от дальности перелета, класса обслуживания, заполненности рейсов 

7)	На основании средней загрузки кресел как по перелету, так и рейсу/направлению можно судить об убыточности как этих самых перелетов, так и рейсов/направлений в общем

8)	можно сделать предварительные выводы об оптимальности подобранных самолетов на отдельные перелёты и рейсы/направления, исходя не только из максимальной дальности полета выбранных самолетов, но и принимая в расчет загруженность рейсов.

9)	Анализ нагрузки и подсчет полётных часов.

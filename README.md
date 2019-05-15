# ![icon] [TSH Transport]

[![Build status]][appveyor]
[![GitHub Release]][releases]

Прием и отправка платежной XML информации по HTTP протоколу в систему 
Единого централизованного платежного шлюза (транспортный шлюз - ТШ, ТШ КБР)
Банка России.

* [Основные возможности программы]
* [Замечания к использованию]
* [Дополнительная информация на сайте Банка России]
* [История версий]
* [Идеи и пожелания, ошибки]
* [Лицензионное соглашение]

-----

Данный скрипт на PowerShell осуществляет прием и отправку платежной XML
информации по HTTP протоколу, представляя собой лёгкую замену УТА и КБР-Н.

## Основные возможности программы

* Простое консольное окно с показом текщего лога;
* Автоматический запуск обмена по истечению периода времени, появлению новых
файлов, нажатию клавиши (пробел - запуск, Esc - выход);
* Все пользовательские настройки вынесены в отдельный текстовый PS1-файл,
снабженный комментариями;
* Подробное логирование. Удобочитаемые текстовые логи;
* Работа по настраиваемому гибкому расписанию (ночью - реже).

## Замечания к использованию

* Распаковать дистрибутивный `zip` из [Releases] в отдельную папку.
* До первого запуска отредактировать файл настроек `Get-Config.ps1`.
* Запускать следует `TshTrans.cmd`.

## Дополнительная информация на сайте Банка России

* [Информация о новых версиях программного обеспечения].

## История версий

Проект наследует идеи [SVK Transport] и поэтому начинается с версии 3.0.0.

Нумерация версий ведется по принципам [семантического версионирования]
со следующими особенностями (для примера - пусть будет версия *1.2.3*):

* Старшая цифра (*1*) меняется, когда сильно 
меняется внешний вид (требуется новое обучение пользователей) или внутренний 
функционал программы (требуется обратить внимание администраторов и сделать 
вдумчивые перенастройки);
* Средняя цифра (*2*) - когда что-то добавляется во внешний вид 
(требуется обратить внимание пользователей - добавлена какая-то их хотелка) 
или добавлен параметр в файл настройки, поведение которого по умолчанию 
ничего для администраторов не меняет;
* Младшая цифра (*3*) - когда в программе сделаны какие-то незначительные 
изменения в коде или исправлены ошибки.

Полная история версий в файле [CHANGELOG].

## Идеи и пожелания, ошибки

Данные для обратной связи находятся на сайте dievdo.ru  
(Всякие хотелки принимаются и по возможности претворяются.)

Есть некоторые [Идеи] развития проекта.
Свои пожелания и сообщения об ошибках лучше размещать в [Issues].

## Лицензионное соглашение

Licensed under the [Apache License, Version 2.0].  
(Вы можете использовать его совершенно свободно без всяких ограничений.)

[Основные возможности программы]: #основные-возможности-программы
[Замечания к использованию]: #замечания-к-использованию
[Дополнительная информация на сайте Банка России]: #дополнительная-информация-на-сайте-банка-россии
[История версий]: #история-версий
[Идеи и пожелания, ошибки]: #идеи-и-пожелания-ошибки
[Лицензионное соглашение]: #лицензионное-соглашение

[Wiki]: https://github.com/diev/TSH-Transport/wiki
[Идеи]: https://github.com/diev/TSH-Transport/projects/1
[Issues]: https://github.com/diev/TSH-Transport/issues
[releases]: https://github.com/diev/TSH-Transport/releases/latest

[CHANGELOG]: CHANGELOG.md
[Apache License, Version 2.0]: LICENSE

[icon]: docs/assets/images/tshtrans.png
[файле]: docs/changelog.md

[TSH Transport]: http://diev.github.io/TSH-Transport
[SVK Transport]: http://diev.github.io/SVK-Transport-hta

[appveyor]: https://ci.appveyor.com/project/diev/tsh-transport-hta
[СВК]: http://www.cbr.ru/mcirabis/itest/
[Информация о новых версиях программного обеспечения]: http://www.cbr.ru/mcirabis/?PrtId=itest (СВК, УТА)
[семантического версионирования]: http://semver.org/lang/ru/

[Build status]: https://ci.appveyor.com/api/projects/status/1mvedcg27p6n7aj0?svg=true
[GitHub Release]: https://img.shields.io/github/release/diev/TSH-Transport.svg
